import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AppConfigService extends ChangeNotifier {
  static final AppConfigService instance = AppConfigService._init();

  static const String _keyDemoMode = 'config_demo_mode_enabled';
  static const String _keyNotifications = 'config_notifications_enabled';
  static const String _keyApiBaseUrl = 'config_api_base_url';

  bool _isDemoMode = false;
  bool _isNotificationsEnabled = true;
  bool _isInitialized = false;

  AppConfigService._init();

  bool get isDemoMode => _isDemoMode;
  bool get isNotificationsEnabled => _isNotificationsEnabled;
  bool get isInitialized => _isInitialized;
  String get baseUrl => ApiConfig.baseUrl;

  /// Retorna el intervalo de sondeo (polling).
  /// En modo Demo: 1 segundo para visualización instantánea.
  /// En modo Normal: 30 segundos para ahorro de batería y red.
  Duration get pollingInterval =>
      _isDemoMode ? const Duration(seconds: 1) : const Duration(seconds: 30);

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _isDemoMode = prefs.getBool(_keyDemoMode) ?? false;
    _isNotificationsEnabled = prefs.getBool(_keyNotifications) ?? true;

    final storedUrl = prefs.getString(_keyApiBaseUrl);
    if (storedUrl != null && storedUrl.trim().isNotEmpty) {
      ApiConfig.setBaseUrl(storedUrl.trim());
    } else {
      ApiConfig.setBaseUrl(ApiConfig.defaultBaseUrl);
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setDemoMode(bool value) async {
    _isDemoMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDemoMode, value);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _isNotificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, value);
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    ApiConfig.setBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiBaseUrl, ApiConfig.baseUrl);
    notifyListeners();
  }
}
