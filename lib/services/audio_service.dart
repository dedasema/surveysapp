import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campaign_models.dart';
import 'package:http_parser/http_parser.dart';

class AudioService {
  static const String baseUrl = 'https://surveys-backend-83d9.onrender.com';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<List<Campaign>> getAudioCampaigns() async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');

    final response = await http.get(
      Uri.parse('$baseUrl/campanas'),
      headers: {
        'accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      // Filtrar solo las campañas de audio (canal_id = 5)
      final audioCampaigns = data
          .where((campaign) => campaign['canal_id'] == 5)
          .map((campaign) => Campaign.fromJson(campaign))
          .toList();
      return audioCampaigns;
    } else {
      throw Exception('Failed to load campaigns: ${response.statusCode}');
    }
  }

  Future<List<AudioSurvey>> getAudioSurveys(String campaignId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/public/entregas/audio?campana_id=$campaignId'),
      headers: {
        'accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((survey) => AudioSurvey.fromJson(survey)).toList();
    } else {
      throw Exception('Failed to load audio surveys: ${response.statusCode}');
    }
  }

  Future<AudioTranscriptionResponse> transcribeAudio(String entregaId, File audioFile) async {
    try {
      final uri = Uri.parse('$baseUrl/public/entregas/$entregaId/audio');
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        'accept': 'application/json',
      });

      // Crear el archivo con el nombre de la entrega_id y especificar el tipo MIME correcto
      final fileName = '$entregaId.wav';

      // Leer los bytes del archivo
      final bytes = await audioFile.readAsBytes();

      // Crear el MultipartFile con el tipo de contenido específico
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: MediaType('audio', 'wav'), // Especificar tipo MIME correcto
        ),
      );

      print('Enviando audio para transcripción...');
      print('Archivo: $fileName');
      print('Tamaño: ${bytes.length} bytes');
      print('Content-Type: audio/wav');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Respuesta STT: ${response.statusCode}');
      print('Cuerpo: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 202) {
        final data = json.decode(response.body);
        return AudioTranscriptionResponse.fromJson(data);
      } else {
        throw Exception('Error en transcripción: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error en transcribeAudio: $e');
      throw Exception('Error al transcribir audio: $e');
    }
  }

  Future<AudioTranscriptionResponse?> checkAudioStatus(String entregaId, {String? taskId}) async {
    try {
      final endpoint = taskId != null && taskId.isNotEmpty
          ? '$baseUrl/tasks/$taskId'
          : '$baseUrl/public/entregas/$entregaId/audio/status';

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {'accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AudioTranscriptionResponse.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error consultando estado de audio: $e');
      return null;
    }
  }

  Future<AudioTranscriptionResponse> pollAudioResult(
    String entregaId, {
    String? taskId,
    void Function(String status)? onStatusChange,
    Duration timeout = const Duration(seconds: 60),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
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
            (statusResp.respuestas.isNotEmpty || statusResp.transcripcion.isNotEmpty)) {
          return statusResp;
        } else if (statusResp.status == 'error' || statusResp.status == 'failed') {
          throw Exception('El procesamiento de audio falló en el servidor.');
        }
      }

      await Future.delayed(pollInterval);
    }

    throw Exception('Tiempo de espera agotado esperando la transcripción de audio.');
  }
}
