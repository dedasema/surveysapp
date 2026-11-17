import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';

class AuthService {
  static const String baseUrl = 'https://surveys-backend-83d9.onrender.com';
  static const _storage = FlutterSecureStorage();

  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyCachedUser = 'cached_user_profile';

  Future<String?> getAccessToken() async {
    try {
      final token = await _storage.read(key: _keyAccessToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    try {
      final token = await _storage.read(key: _keyRefreshToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken);
  }

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

        // Guardar tokens de forma segura y en SharedPreferences para máxima compatibilidad
        try {
          await _storage.write(key: _keyAccessToken, value: loginResponse.accessToken);
          if (loginResponse.refreshToken != null) {
            await _storage.write(key: _keyRefreshToken, value: loginResponse.refreshToken);
          }
        } catch (_) {}

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyAccessToken, loginResponse.accessToken);
        if (loginResponse.refreshToken != null) {
          await prefs.setString(_keyRefreshToken, loginResponse.refreshToken!);
        }

        // Cache inicial con el email logueado
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
      print('Error en login: $e');
      return null;
    }
  }

  Future<bool> refreshToken() async {
    try {
      final currentRefreshToken = await getRefreshToken();
      if (currentRefreshToken == null) return false;

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
        final refreshData = TokenRefreshResponse.fromJson(jsonDecode(response.body));
        try {
          await _storage.write(key: _keyAccessToken, value: refreshData.accessToken);
          if (refreshData.refreshToken != null) {
            await _storage.write(key: _keyRefreshToken, value: refreshData.refreshToken);
          }
        } catch (_) {}

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyAccessToken, refreshData.accessToken);
        if (refreshData.refreshToken != null) {
          await prefs.setString(_keyRefreshToken, refreshData.refreshToken!);
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Error renovando token: $e');
      return false;
    }
  }

  Future<http.Response> authenticatedGet(Uri uri, {Map<String, String>? headers}) async {
    String? token = await getAccessToken();
    final combinedHeaders = {
      'accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };

    var response = await http.get(uri, headers: combinedHeaders);

    // Si expira el token (401), intentamos renovar automáticamente y reintentar
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

  Future<http.Response> authenticatedPost(Uri uri, {Map<String, String>? headers, Object? body}) async {
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
      print('Error obteniendo usuario del servidor: $e');
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

  Future<void> logout() async {
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
