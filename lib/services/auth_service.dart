import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';
import '../config/api_config.dart';

/// Servicio de autenticación con tokens JWT en almacenamiento seguro y refresco rotativo.
class AuthService {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  static String get baseUrl => ApiConfig.baseUrl;

  /// Almacenamiento seguro en hardware (Android Keystore / EncryptedSharedPreferences)
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyCachedUser = 'cached_user_profile';

  /// Stream para notificar a la interfaz cuando la sesión expira o es revocada
  final _sessionExpiredController = StreamController<bool>.broadcast();
  Stream<bool> get sessionExpiredStream => _sessionExpiredController.stream;

  /// Obtiene el token de acceso actual desde almacenamiento seguro
  Future<String?> getAccessToken() async {
    try {
      final token = await _storage.read(key: _keyAccessToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      debugPrint('Error leyendo access_token seguro: $e');
    }
    return null;
  }

  /// Obtiene el refresh token actual desde almacenamiento seguro
  Future<String?> getRefreshToken() async {
    try {
      final token = await _storage.read(key: _keyRefreshToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      debugPrint('Error leyendo refresh_token seguro: $e');
    }
    return null;
  }

  /// Inicia sesión con correo y contraseña. Los tokens se guardan exclusivamente en almacenamiento seguro.
  Future<LoginResponse?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final loginResponse = LoginResponse.fromJson(jsonDecode(response.body));

        // Guardado seguro exclusivo (nunca en SharedPreferences en texto plano)
        await _storage.write(
            key: _keyAccessToken, value: loginResponse.accessToken);
        if (loginResponse.refreshToken != null) {
          await _storage.write(
              key: _keyRefreshToken, value: loginResponse.refreshToken);
        }

        // Limpieza de tokens residuales en texto plano si existían de versiones anteriores
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyAccessToken);
        await prefs.remove(_keyRefreshToken);

        // Cache del perfil de usuario no sensible para modo offline
        final initialUser = User(
          id: 'user-${email.hashCode}',
          email: email,
          rol: 'operador',
          creadoEn: DateTime.now(),
          tipo: 'operador',
          nombre: email.contains('@') ? email.split('@')[0] : 'Operador',
          telefono: '',
          estado: 'activo',
        );
        await prefs.setString(_keyCachedUser, jsonEncode(initialUser.toJson()));

        return loginResponse;
      }
      return null;
    } catch (e) {
      debugPrint('Error en login: $e');
      return null;
    }
  }

  /// Refresco rotativo de token: el servidor invalida el refresh_token anterior y devuelve uno nuevo.
  /// Si el refresco falla (token revocado/expirado), cierra la sesión sin tocar las respuestas locales en SQLite.
  Future<bool> refreshToken() async {
    try {
      final currentRefreshToken = await getRefreshToken();
      if (currentRefreshToken == null) {
        _triggerSessionExpired();
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refresh_token': currentRefreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final refreshData =
            TokenRefreshResponse.fromJson(jsonDecode(response.body));

        // Guardar nuevo par de tokens rotados
        await _storage.write(
            key: _keyAccessToken, value: refreshData.accessToken);
        if (refreshData.refreshToken != null) {
          await _storage.write(
              key: _keyRefreshToken, value: refreshData.refreshToken);
        }
        return true;
      }

      // Si el servidor responde 401/403 o no puede renovar, el refresh token es inválido
      debugPrint(
          'Refresco de token rechazado por el servidor (${response.statusCode}): ${response.body}');
      await _handleExpiredSession();
      return false;
    } catch (e) {
      debugPrint('Error de red renovando token: $e');
      // En error de red transitorio, no cerramos sesión forzosa para permitir trabajo offline
      return false;
    }
  }

  void _triggerSessionExpired() {
    _sessionExpiredController.add(true);
  }

  Future<void> _handleExpiredSession() async {
    try {
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
    } catch (_) {}
    _triggerSessionExpired();
  }

  /// Realiza un GET autenticado con reintento automático tras refresco rotativo si recibe 401
  Future<http.Response> authenticatedGet(Uri uri,
      {Map<String, String>? headers}) async {
    String? token = await getAccessToken();
    final combinedHeaders = {
      'accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };

    var response = await http.get(uri, headers: combinedHeaders);

    if (response.statusCode == 401) {
      final renewed = await refreshToken();
      if (renewed) {
        token = await getAccessToken();
        combinedHeaders['Authorization'] = 'Bearer $token';
        response = await http.get(uri, headers: combinedHeaders);
      }
    }

    return response;
  }

  /// Realiza un POST autenticado con reintento automático tras refresco rotativo si recibe 401
  Future<http.Response> authenticatedPost(Uri uri,
      {Map<String, String>? headers, Object? body}) async {
    String? token = await getAccessToken();
    final combinedHeaders = {
      'accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };

    var response = await http.post(uri, headers: combinedHeaders, body: body);

    if (response.statusCode == 401) {
      final renewed = await refreshToken();
      if (renewed) {
        token = await getAccessToken();
        combinedHeaders['Authorization'] = 'Bearer $token';
        response = await http.post(uri, headers: combinedHeaders, body: body);
      }
    }

    return response;
  }

  /// Obtiene la información del usuario autenticado o recurre a la caché local si está offline
  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await authenticatedGet(Uri.parse('$baseUrl/auth/me'));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final user = User.fromJson(decoded);
        await prefs.setString(_keyCachedUser, jsonEncode(user.toJson()));
        return user;
      }
    } catch (e) {
      debugPrint(
          'Aviso obteniendo usuario del servidor (posible modo offline): $e');
    }

    // Fallback 1: Recuperar perfil de caché local
    final cachedJson = prefs.getString(_keyCachedUser);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        return User.fromJson(jsonDecode(cachedJson));
      } catch (_) {}
    }

    // Fallback 2: Si hay token activo pero falló la red, devolver usuario por defecto para no bloquear la UI
    final token = await getAccessToken();
    if (token != null && token.isNotEmpty) {
      return User(
        id: 'operador-campo',
        email: 'operador@encuestas.com',
        rol: 'operador',
        creadoEn: DateTime.now(),
        tipo: 'operador',
        nombre: 'Operador de Campo',
        telefono: '',
        estado: 'activo',
      );
    }

    return null;
  }

  /// Cierre de sesión voluntario: revoca el token en el servidor e invalida los tokens locales en almacenamiento seguro.
  /// NO elimina las respuestas ni encuestas locales almacenadas en SQLite.
  Future<void> logout() async {
    try {
      final refreshTokenValue = await getRefreshToken();
      if (refreshTokenValue != null) {
        await http
            .post(
              Uri.parse('$baseUrl/auth/logout'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh_token': refreshTokenValue}),
            )
            .timeout(const Duration(seconds: 3));
      }
    } catch (_) {}

    try {
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyCachedUser);
  }
}
