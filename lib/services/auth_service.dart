import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_models.dart';

class AuthService {
  static const String baseUrl = 'https://surveys-backend-83d9.onrender.com';
  static const _storage = FlutterSecureStorage();

  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
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

        // Guardar tokens de forma segura y cifrada en hardware nativo
        await _storage.write(key: _keyAccessToken, value: loginResponse.accessToken);
        if (loginResponse.refreshToken != null) {
          await _storage.write(key: _keyRefreshToken, value: loginResponse.refreshToken);
        }

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
        await _storage.write(key: _keyAccessToken, value: refreshData.accessToken);
        if (refreshData.refreshToken != null) {
          await _storage.write(key: _keyRefreshToken, value: refreshData.refreshToken);
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
    try {
      final response = await authenticatedGet(Uri.parse('$baseUrl/auth/me'));

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error obteniendo usuario: $e');
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
  }
}
