import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Pushes synthetic telemetry into Firebase RTDB only.
/// The Flutter UI must read exclusively from Firebase listeners — not from this class.
class LiveTelemetrySimulator {
  LiveTelemetrySimulator({
    this.interval = const Duration(seconds: 3),
    this.scenario = 'mixed',
    this.dbUrl = 'https://ecodrive-85155-default-rtdb.firebaseio.com',
    this.apiKey = 'AIzaSyBjlXZlC8fQiNmSLMzmQF-m5PjUxkxLWlc',
    this.email = 'ecodrive@test.com',
    this.password = 'test1234',
  });

  static const int cleanAir = 200;
  static const int maxSmoke = 700;
  static const int alertThreshold = 400;

  final Duration interval;
  final String scenario;
  final String dbUrl;
  final String apiKey;
  final String email;
  final String password;

  final _rng = Random();
  final _client = http.Client();
  Timer? _timer;
  int _tick = 0;
  _ScenarioProfile _active = _ScenarioProfile.normal;
  bool _running = false;
  bool _publishing = false;

  String? _idToken;
  DateTime? _tokenExpiresAt;

  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;
    _active = _pickProfile(scenario);
    debugPrint(
      '[SIMULATOR] Writing to Firebase only '
      '(scenario=$scenario every ${interval.inSeconds}s)',
    );
    unawaited(_publishOnce());
    _timer = Timer.periodic(interval, (_) => unawaited(_publishOnce()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _client.close();
    debugPrint('[SIMULATOR] Stopped');
  }

  Future<void> _publishOnce() async {
    if (_publishing) return;
    _publishing = true;
    try {
      final reading = _nextReading();
      final payload = {
        'rawGas': reading['rawGas'],
        'temperature': reading['temperature'],
        'humidity': reading['humidity'],
        'emissionScore': reading['emissionScore'],
        'timestamp': reading['timestamp'],
      };

      await _put('carEmissions/liveData', payload);
      await _put(
        'carEmissions/history/${reading['dateFolder']}/${reading['timeKey']}',
        payload,
      );

      final score = reading['emissionScore'] as int;
      if (score >= alertThreshold) {
        final alertId = '${reading['dateFolder']}_${reading['timeKey']}';
        await _put('carEmissions/alerts/$alertId', {
          'emissionScore': score,
          'message': 'High emission event',
          'timestamp': reading['timestamp'],
        });
        debugPrint('[SIMULATOR] Alert pushed score=$score');
      }

      debugPrint(
        '[SIMULATOR] Pushed → Firebase '
        '[${reading['scenario']}] score=$score rawGas=${reading['rawGas']}',
      );
    } catch (e) {
      debugPrint('[SIMULATOR] Firebase push failed: $e');
    } finally {
      _publishing = false;
    }
  }

  Future<String> _ensureToken() async {
    final expires = _tokenExpiresAt;
    if (_idToken != null &&
        expires != null &&
        DateTime.now().isBefore(expires.subtract(const Duration(seconds: 60)))) {
      return _idToken!;
    }

    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey',
    );
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Auth failed HTTP ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final token = body['idToken'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Auth failed: missing idToken');
    }
    final expiresIn = int.tryParse('${body['expiresIn'] ?? 3600}') ?? 3600;
    _idToken = token;
    _tokenExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    debugPrint('[SIMULATOR] Signed in as $email for Firebase writes');
    return token;
  }

  Future<void> _put(String path, Map<String, dynamic> payload) async {
    final token = await _ensureToken();
    final clean = path.replaceAll(RegExp(r'^/+|/+$'), '');
    final uri = Uri.parse('$dbUrl/$clean.json?auth=$token');
    final res = await _client.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('PUT $clean failed HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Map<String, dynamic> _nextReading() {
    _maybeRotateMixed();
    _tick += 1;
    final profile = _active;

    // Force a hard peak of 500 around the midpoint (~25th record, then every 50).
    final forcePeak500 = _tick % 50 == 25;

    double raw;
    int score;
    if (forcePeak500) {
      raw = maxSmoke.toDouble();
      score = 500;
      debugPrint('[SIMULATOR] Forced peak score=500 at record #$_tick');
    } else {
      final drift = 8.0 * sin(_tick / 17.0);
      raw = _gauss(profile.rawGasCenter + drift, profile.rawGasStd);
      if (_rng.nextDouble() < profile.spikeChance) {
        raw += (0.4 + _rng.nextDouble() * 0.6) * profile.spikeMagnitude;
      }
      raw = raw.clamp(180.0, 750.0);
      score = _emissionScoreFromRawGas(raw);
    }

    final temp = _gauss(profile.tempCenter, 0.45);
    final humidity = _gauss(profile.humidityCenter, 1.2).clamp(20.0, 95.0);

    final now = DateTime.now();
    final ts =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final dateFolder =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final timeKey =
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}-'
        '${now.second.toString().padLeft(2, '0')}';

    return {
      'rawGas': double.parse(raw.toStringAsFixed(2)),
      'temperature': double.parse(temp.toStringAsFixed(2)),
      'humidity': double.parse(humidity.toStringAsFixed(2)),
      'emissionScore': score,
      'timestamp': ts,
      'dateFolder': dateFolder,
      'timeKey': timeKey,
      'scenario': profile.name,
    };
  }

  void _maybeRotateMixed() {
    if (scenario != 'mixed') return;
    if (_tick > 0 && _tick % 12 == 0) {
      _active = _ScenarioProfile.all[_rng.nextInt(_ScenarioProfile.all.length)];
      debugPrint('[SIMULATOR] style → ${_active.name}');
    }
  }

  _ScenarioProfile _pickProfile(String name) {
    if (name == 'mixed') {
      return _ScenarioProfile.all[_rng.nextInt(_ScenarioProfile.all.length)];
    }
    return _ScenarioProfile.all.firstWhere(
      (p) => p.name == name,
      orElse: () => _ScenarioProfile.normal,
    );
  }

  int _emissionScoreFromRawGas(double rawGas) {
    final t = (rawGas - cleanAir) / (maxSmoke - cleanAir);
    final score = 50.0 + t * 450.0;
    return score.round().clamp(50, 500);
  }

  double _gauss(double mean, double std) {
    final u1 = _rng.nextDouble().clamp(1e-9, 1.0);
    final u2 = _rng.nextDouble();
    final z = sqrt(-2.0 * log(u1)) * cos(2 * pi * u2);
    return mean + std * z;
  }
}

class _ScenarioProfile {
  const _ScenarioProfile({
    required this.name,
    required this.rawGasCenter,
    required this.rawGasStd,
    required this.spikeChance,
    required this.spikeMagnitude,
    required this.tempCenter,
    required this.humidityCenter,
  });

  final String name;
  final double rawGasCenter;
  final double rawGasStd;
  final double spikeChance;
  final double spikeMagnitude;
  final double tempCenter;
  final double humidityCenter;

  static const eco = _ScenarioProfile(
    name: 'eco',
    rawGasCenter: 240,
    rawGasStd: 12,
    spikeChance: 0.02,
    spikeMagnitude: 40,
    tempCenter: 28,
    humidityCenter: 55,
  );
  static const normal = _ScenarioProfile(
    name: 'normal',
    rawGasCenter: 320,
    rawGasStd: 18,
    spikeChance: 0.08,
    spikeMagnitude: 80,
    tempCenter: 29,
    humidityCenter: 58,
  );
  static const aggressive = _ScenarioProfile(
    name: 'aggressive',
    rawGasCenter: 480,
    rawGasStd: 35,
    spikeChance: 0.25,
    spikeMagnitude: 140,
    tempCenter: 31,
    humidityCenter: 52,
  );
  static const idle = _ScenarioProfile(
    name: 'idle',
    rawGasCenter: 265,
    rawGasStd: 4,
    spikeChance: 0.01,
    spikeMagnitude: 20,
    tempCenter: 27.5,
    humidityCenter: 60,
  );
  static const critical = _ScenarioProfile(
    name: 'critical',
    rawGasCenter: 620,
    rawGasStd: 40,
    spikeChance: 0.35,
    spikeMagnitude: 100,
    tempCenter: 33,
    humidityCenter: 48,
  );

  static const all = [eco, normal, aggressive, idle, critical];
}
