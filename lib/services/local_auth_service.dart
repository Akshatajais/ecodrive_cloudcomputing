import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// Custom user accounts stored in Firebase RTDB.
/// Does NOT use Firebase Authentication — only Realtime Database + local session.
class LocalAuthService {
  LocalAuthService({
    this.dbUrl = 'https://ecodrive-85155-default-rtdb.firebaseio.com',
    this.apiKey = 'AIzaSyBjlXZlC8fQiNmSLMzmQF-m5PjUxkxLWlc',
    this.writerEmail = 'ecodrive@test.com',
    this.writerPassword = 'test1234',
  });

  static const _sessionUsernameKey = 'session_username';
  static const _sessionNameKey = 'session_name';
  static const _sessionPhoneKey = 'session_phone';
  static const _sessionCarKey = 'session_car';

  final String dbUrl;
  final String apiKey;
  final String writerEmail;
  final String writerPassword;

  final _client = http.Client();
  String? _idToken;
  DateTime? _tokenExpiresAt;

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Username key for RTDB path (phone digits preferred).
  static String normalizeUsername(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 8) return digits;
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  Future<AppUser?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_sessionUsernameKey);
    if (username == null || username.isEmpty) return null;
    return AppUser(
      username: username,
      name: prefs.getString(_sessionNameKey) ?? '',
      phone: prefs.getString(_sessionPhoneKey) ?? '',
      carNumber: prefs.getString(_sessionCarKey) ?? '',
    );
  }

  Future<void> _saveSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionUsernameKey, user.username);
    await prefs.setString(_sessionNameKey, user.name);
    await prefs.setString(_sessionPhoneKey, user.phone);
    await prefs.setString(_sessionCarKey, user.carNumber);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUsernameKey);
    await prefs.remove(_sessionNameKey);
    await prefs.remove(_sessionPhoneKey);
    await prefs.remove(_sessionCarKey);
  }

  Future<AppUser> register({
    required String name,
    required String phone,
    required String password,
    required String carNumber,
  }) async {
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();
    final trimmedCar = carNumber.trim().toUpperCase();
    final username = normalizeUsername(trimmedPhone);

    if (trimmedName.isEmpty) {
      throw StateError('Name is required');
    }
    if (username.isEmpty) {
      throw StateError('Phone number is required');
    }
    if (password.length < 4) {
      throw StateError('Password must be at least 4 characters');
    }
    if (trimmedCar.isEmpty) {
      throw StateError('Car number is required');
    }

    final existing = await _getUserMap(username);
    if (existing != null) {
      throw StateError('An account with this phone already exists');
    }

    final user = AppUser(
      username: username,
      name: trimmedName,
      phone: trimmedPhone,
      carNumber: trimmedCar,
      createdAt: DateTime.now().toIso8601String(),
    );

    await _put(
      'appUsers/$username',
      user.toJson(passwordHash: hashPassword(password)),
    );
    await _saveSession(user);
    return user;
  }

  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    final key = normalizeUsername(username);
    if (key.isEmpty) {
      throw StateError('Username is required');
    }
    if (password.isEmpty) {
      throw StateError('Password is required');
    }

    final data = await _getUserMap(key);
    if (data == null) {
      throw StateError('No account found for this username');
    }

    final storedHash = '${data['passwordHash'] ?? ''}';
    if (storedHash.isEmpty || storedHash != hashPassword(password)) {
      throw StateError('Incorrect password');
    }

    final user = AppUser.fromJson(data);
    await _saveSession(user);
    return user;
  }

  Future<Map<String, dynamic>?> _getUserMap(String username) async {
    final token = await _ensureWriterToken();
    final uri = Uri.parse('$dbUrl/appUsers/$username.json?auth=$token');
    final res = await _client.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Could not reach Firebase (${res.statusCode})');
    }
    if (res.body.isEmpty || res.body == 'null') return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _put(String path, Map<String, dynamic> payload) async {
    final token = await _ensureWriterToken();
    final clean = path.replaceAll(RegExp(r'^/+|/+$'), '');
    final uri = Uri.parse('$dbUrl/$clean.json?auth=$token');
    final res = await _client.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Failed to save user (${res.statusCode})');
    }
  }

  /// Uses a shared writer account only to write/read RTDB — not end-user Auth.
  Future<String> _ensureWriterToken() async {
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
        'email': writerEmail,
        'password': writerPassword,
        'returnSecureToken': true,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Firebase write access failed. Check connection.');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final token = body['idToken'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Firebase write access failed');
    }
    final expiresIn = int.tryParse('${body['expiresIn'] ?? 3600}') ?? 3600;
    _idToken = token;
    _tokenExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    return token;
  }
}
