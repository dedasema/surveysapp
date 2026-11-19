import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campaign_models.dart';
import '../config/api_config.dart';
import 'package:http_parser/http_parser.dart';
import 'app_config_service.dart';
import 'notification_service.dart';
import 'auth_service.dart';
import 'database_helper.dart';

class AudioService {
  static String get baseUrl => ApiConfig.baseUrl;
  final AuthService _authService = AuthService();

  Future<String?> _getToken() async {
    final token = await _authService.getAccessToken();
    if (token != null && token.isNotEmpty) return token;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<List<Campaign>> getAudioCampaigns() async {
    try {
      final response = await _authService.authenticatedGet(
        Uri.parse('$baseUrl/campanas'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final audioCampaigns = data
            .where((campaign) =>
                campaign['canal_id'] == 5 || campaign['canal_id'] == null)
            .map((campaign) => Campaign.fromJson(campaign))
            .toList();

        // Guardado local en SQLite para soporte de Modo Avión
        try {
          await DatabaseHelper.instance.cacheCampaigns(audioCampaigns);
        } catch (e) {
          debugPrint('Error guardando campañas en caché local: $e');
        }
        return audioCampaigns;
      }
    } catch (e) {
      debugPrint('Aviso obteniendo campañas por red (posible modo avión): $e');
    }

    // Fallback: Recuperar campañas guardadas localmente en SQLite
    final cached = await DatabaseHelper.instance.getCachedCampaigns();
    if (cached.isNotEmpty) {
      return cached;
    }

    throw Exception('Sin conexión y no hay campañas guardadas localmente.');
  }

  Future<List<AudioSurvey>> getAudioSurveys(String campaignId) async {
    // 1. Intentar obtener el detalle completo autenticado de la campaña
    try {
      final response = await _authService.authenticatedGet(
        Uri.parse('$baseUrl/campanas/$campaignId/full-detail'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final plantillaJson = data['plantilla'] as Map<String, dynamic>?;
        final plantilla = plantillaJson != null
            ? SurveyTemplate.fromJson(plantillaJson)
            : SurveyTemplate(
                id: campaignId,
                nombre: (data['nombre'] ?? 'Encuesta de Audio').toString(),
                preguntas: [],
              );

        final List<dynamic> entregasList =
            data['entregas'] as List<dynamic>? ?? [];

        List<AudioSurvey> surveys = [];
        if (entregasList.isNotEmpty) {
          surveys = entregasList.map((entrega) {
            final dest = entrega['destinatario'];
            String? destinatarioNombre;
            if (dest is Map<String, dynamic>) {
              destinatarioNombre =
                  dest['nombre'] ?? dest['email'] ?? dest['telefono'];
            } else if (dest is String) {
              destinatarioNombre = dest;
            }
            return AudioSurvey(
              id: (entrega['id'] ?? '').toString(),
              plantilla: plantilla,
              destinatario: destinatarioNombre,
              creadoEn:
                  (entrega['enviado_en'] ?? data['creado_en'])?.toString(),
              respondidoEn: entrega['respondido_en']?.toString(),
            );
          }).toList();
        } else {
          // Si la campaña no tiene entregas creadas todavía, creamos una entrega de audio automáticamente
          try {
            final canalId = data['canal_id'] ?? 5;
            final createResp = await _authService.authenticatedPost(
              Uri.parse('$baseUrl/campanas/$campaignId/entregas'),
              body: json.encode({'canal_id': canalId}),
            );
            if (createResp.statusCode == 200 || createResp.statusCode == 201) {
              final newEntrega = json.decode(createResp.body);
              surveys = [
                AudioSurvey(
                  id: (newEntrega['id'] ?? '').toString(),
                  plantilla: plantilla,
                  destinatario: 'Nueva Encuesta',
                  creadoEn: DateTime.now().toIso8601String(),
                )
              ];
            }
          } catch (e) {
            debugPrint('Aviso creando entrega automática: $e');
          }

          if (surveys.isEmpty) {
            surveys = [
              AudioSurvey(
                id: campaignId,
                plantilla: plantilla,
                destinatario: 'Operador de Campo',
                creadoEn: DateTime.now().toIso8601String(),
              )
            ];
          }
        }

        // Guardado local en SQLite para soporte de Modo Avión
        try {
          await DatabaseHelper.instance.cacheSurveys(campaignId, surveys);
        } catch (e) {
          debugPrint('Error guardando encuestas en caché SQLite: $e');
        }
        return surveys;
      }
    } catch (e) {
      debugPrint('Aviso: Falló /campanas/$campaignId/full-detail: $e');
    }

    // 2. Fallback: listar entregas directamente desde /campanas/{id}/entregas
    try {
      final response = await _authService.authenticatedGet(
        Uri.parse('$baseUrl/campanas/$campaignId/entregas'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final defaultTemplate = SurveyTemplate(
          id: campaignId,
          nombre: 'Encuesta de Audio',
          preguntas: [],
        );
        final surveys = data.map((entrega) {
          final dest = entrega['destinatario'];
          String? destinatarioNombre;
          if (dest is Map<String, dynamic>) {
            destinatarioNombre = dest['nombre'] ?? dest['email'];
          }
          return AudioSurvey(
            id: (entrega['id'] ?? '').toString(),
            plantilla: defaultTemplate,
            destinatario: destinatarioNombre,
            creadoEn:
                (entrega['enviado_en'] ?? entrega['creado_en'])?.toString(),
            respondidoEn: entrega['respondido_en']?.toString(),
          );
        }).toList();

        try {
          await DatabaseHelper.instance.cacheSurveys(campaignId, surveys);
        } catch (_) {}
        return surveys;
      }
    } catch (e) {
      debugPrint('Aviso: Falló fallback /campanas/$campaignId/entregas: $e');
    }

    // 3. Fallback definitivo en Modo Avión: Recuperar encuestas cacheadas en SQLite
    final localCached =
        await DatabaseHelper.instance.getCachedSurveys(campaignId);
    if (localCached.isNotEmpty) {
      return localCached;
    }

    throw Exception(
        'Sin conexión y no hay encuestas descargadas localmente para esta campaña.');
  }

  Future<AudioTranscriptionResponse> transcribeAudio(
      String entregaId, File audioFile) async {
    final token = await _getToken();
    final fileName = '$entregaId.wav';
    final bytes = await audioFile.readAsBytes();

    // 1. Probar primero el endpoint oficial RF18: POST /encuestas/{entrega_id}/audio-respuesta
    try {
      final uri = Uri.parse('$baseUrl/encuestas/$entregaId/audio-respuesta');
      final request = http.MultipartRequest('POST', uri);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['accept'] = 'application/json';

      request.files.add(
        http.MultipartFile.fromBytes(
          'archivo',
          bytes,
          filename: fileName,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        final data = json.decode(response.body);
        return AudioTranscriptionResponse.fromJson(data);
      }
    } catch (e) {
      debugPrint('Aviso en /encuestas/$entregaId/audio-respuesta: $e');
    }

    // 2. Fallback: Probar ruta legacy POST /public/entregas/{entrega_id}/audio
    try {
      final uri = Uri.parse('$baseUrl/public/entregas/$entregaId/audio');
      final request = http.MultipartRequest('POST', uri);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['accept'] = 'application/json';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        final data = json.decode(response.body);
        return AudioTranscriptionResponse.fromJson(data);
      } else {
        throw Exception(
            'Error en transcripción: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al transcribir audio: $e');
    }
  }

  Future<AudioTranscriptionResponse?> checkAudioStatus(String entregaId,
      {String? taskId}) async {
    try {
      final token = await _getToken();
      final headers = {
        'accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      // 1. Probar endpoint RF18
      final audioId = taskId ?? entregaId;
      try {
        final resp = await http.get(
          Uri.parse('$baseUrl/encuestas/audio-respuesta/$audioId/estado'),
          headers: headers,
        );
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          return AudioTranscriptionResponse.fromJson(data);
        }
      } catch (_) {}

      // 2. Probar task worker
      if (taskId != null && taskId.isNotEmpty) {
        try {
          final resp = await http.get(
            Uri.parse('$baseUrl/tasks/$taskId'),
            headers: headers,
          );
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body);
            return AudioTranscriptionResponse.fromJson(data);
          }
        } catch (_) {}
      }

      // 3. Fallback legado
      final legacyResp = await http.get(
        Uri.parse('$baseUrl/public/entregas/$entregaId/audio/status'),
        headers: headers,
      );
      if (legacyResp.statusCode == 200) {
        final data = json.decode(legacyResp.body);
        return AudioTranscriptionResponse.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error consultando estado de audio: $e');
      return null;
    }
  }

  Future<AudioTranscriptionResponse> pollAudioResult(
    String entregaId, {
    String? taskId,
    void Function(String status)? onStatusChange,
    Duration timeout = const Duration(seconds: 60),
    Duration? pollInterval,
  }) async {
    final effectiveInterval =
        pollInterval ?? AppConfigService.instance.pollingInterval;
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      final statusResp = await checkAudioStatus(entregaId, taskId: taskId);

      if (statusResp != null) {
        if (onStatusChange != null) {
          onStatusChange(statusResp.status);
        }

        if (statusResp.status == 'ok' ||
            statusResp.status == 'completed' ||
            statusResp.status == 'completado' ||
            (statusResp.respuestas.isNotEmpty ||
                statusResp.transcripcion.isNotEmpty)) {
          // Disparar notificación local nativa de éxito
          final previewText = statusResp.transcripcion.isNotEmpty
              ? (statusResp.transcripcion.length > 50
                  ? '${statusResp.transcripcion.substring(0, 50)}...'
                  : statusResp.transcripcion)
              : null;
          await NotificationService.instance.notifyAudioTranscription(
            entregaId: entregaId,
            isSuccess: true,
            details:
                previewText != null ? 'Transcripción: "$previewText"' : null,
          );
          return statusResp;
        } else if (statusResp.status == 'error' ||
            statusResp.status == 'failed') {
          await NotificationService.instance.notifyAudioTranscription(
            entregaId: entregaId,
            isSuccess: false,
            details: 'El procesamiento de audio falló en el servidor.',
          );
          throw Exception('El procesamiento de audio falló en el servidor.');
        }
      }

      await Future.delayed(effectiveInterval);
    }

    await NotificationService.instance.notifyAudioTranscription(
      entregaId: entregaId,
      isSuccess: false,
      details: 'Tiempo de espera agotado al transcribir el audio.',
    );
    throw Exception(
        'Tiempo de espera agotado esperando la transcripción de audio.');
  }
}
