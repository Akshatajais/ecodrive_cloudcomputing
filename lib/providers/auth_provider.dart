import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/local_auth_service.dart';
import '../services/settings_service.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider({
    LocalAuthService? authService,
    SettingsService? settingsService,
  })  : _auth = authService ?? LocalAuthService(),
        _settings = settingsService ?? SettingsService();

  final LocalAuthService _auth;
  final SettingsService _settings;

  AppUser? _user;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _loading;
  bool get isBusy => _busy;
  String? get error => _error;

  Future<void> bootstrap() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _auth.getSavedSession();
      if (_user != null && _user!.carNumber.isNotEmpty) {
        await _settings.setVehicleId(_user!.carNumber);
      }
    } catch (e) {
      _error = e.toString();
      _user = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String phone,
    required String password,
    required String carNumber,
  }) async {
    return _run(() async {
      final user = await _auth.register(
        name: name,
        phone: phone,
        password: password,
        carNumber: carNumber,
      );
      await _settings.setVehicleId(user.carNumber);
      _user = user;
    });
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    return _run(() async {
      final user = await _auth.login(
        username: username,
        password: password,
      );
      if (user.carNumber.isNotEmpty) {
        await _settings.setVehicleId(user.carNumber);
      }
      _user = user;
    });
  }

  Future<void> logout() async {
    await _auth.clearSession();
    _user = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      _error = e is StateError ? e.message : e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
