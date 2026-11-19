import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Modelo de datos de version.json
class AppVersionInfo {
  final String version;
  final double tamanoMb;
  final String sha256;
  final String fecha;
  final String androidMinimo;
  final List<String> novedades;
  final String apkUrl;

  AppVersionInfo({
    required this.version,
    required this.tamanoMb,
    required this.sha256,
    required this.fecha,
    required this.androidMinimo,
    required this.novedades,
    required this.apkUrl,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    final rawNovedades = json['novedades'] ?? json['features'] ?? [];
    final List<String> novedadesList = (rawNovedades is List)
        ? rawNovedades.map((e) => e.toString()).toList()
        : [];

    final rawSize = json['tamano_mb'] ?? json['tamano'] ?? 52.3;
    final double sizeMb = (rawSize is num) ? rawSize.toDouble() : 52.3;

    return AppVersionInfo(
      version: (json['version'] ?? '1.0.0').toString(),
      tamanoMb: sizeMb,
      sha256: (json['sha256'] ?? '').toString(),
      fecha: (json['fecha'] ?? json['updatedAt'] ?? '').toString(),
      androidMinimo: (json['android_minimo'] ??
              json['minAndroidVersion'] ??
              'Android 7.0 (API 24)')
          .toString(),
      novedades: novedadesList,
      apkUrl: (json['apkUrl'] ?? '/downloads/surveysaas.apk').toString(),
    );
  }
}

/// Servicio que comprueba actualizaciones contra version.json como máximo una vez al día
class VersionCheckService {
  static final VersionCheckService instance = VersionCheckService._internal();
  factory VersionCheckService() => instance;
  VersionCheckService._internal();

  static const String currentVersion = '1.0.0';
  static const String _keyLastCheck = 'version_check_last_timestamp';

  /// Comprueba en silencio si hay una versión nueva disponible
  Future<AppVersionInfo?> checkForUpdate({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!force) {
        final lastCheckStr = prefs.getString(_keyLastCheck);
        if (lastCheckStr != null) {
          final lastCheck = DateTime.tryParse(lastCheckStr);
          if (lastCheck != null) {
            final difference = DateTime.now().difference(lastCheck);
            if (difference.inHours < 24) {
              // Ya se consultó hoy, continúa en silencio
              return null;
            }
          }
        }
      }

      // Marcar timestamp de la consulta actual
      await prefs.setString(_keyLastCheck, DateTime.now().toIso8601String());

      final url = ApiConfig.versionJsonUrl;
      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final versionInfo = AppVersionInfo.fromJson(data);

        if (_isVersionNewer(versionInfo.version, currentVersion)) {
          return versionInfo;
        }
      }
    } catch (e) {
      // Si no hay red o la consulta falla, la app sigue en silencio sin interrumpir al operador
      debugPrint(
          'Aviso: Verificación de versión no disponible en este momento: $e');
    }
    return null;
  }

  /// Compara dos versiones semánticas (ej: '1.0.1' > '1.0.0')
  bool _isVersionNewer(String remote, String local) {
    try {
      final remoteParts =
          remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final localParts =
          local.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < remoteParts.length && i < localParts.length; i++) {
        if (remoteParts[i] > localParts[i]) return true;
        if (remoteParts[i] < localParts[i]) return false;
      }
      return remoteParts.length > localParts.length;
    } catch (_) {
      return false;
    }
  }

  /// Muestra el modal con las novedades de la versión
  void showUpdateDialog(BuildContext context, AppVersionInfo info) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.system_update_alt,
                  color: Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 10),
            Text('Nueva Versión ${info.version}',
                style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tamaño: ${info.tamanoMb} MB  •  ${info.androidMinimo}',
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            const Text(
              'Novedades:',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            ...info.novedades.map((nov) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          nov,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Más tarde'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Descargando actualización APK...'),
                ),
              );
            },
            child: const Text('Descargar APK'),
          ),
        ],
      ),
    );
  }
}
