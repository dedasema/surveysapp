import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../config/api_config.dart';

/// Servicio de reconocimiento óptico de caracteres (OCR) para digitalización de formularios físicos
class OCRService {
  static String get baseUrl => ApiConfig.baseUrl;

  /// Procesa una fotografía de formulario en papel enviándola al backend para lectura OCR
  Future<Map<String, dynamic>?> processImage(File imageFile,
      {String? entregaId}) async {
    try {
      final uri = Uri.parse('$baseUrl/public/entregas/ocr');
      var request = http.MultipartRequest('POST', uri);

      if (entregaId != null && entregaId.isNotEmpty) {
        request.fields['entrega_id'] = entregaId;
      }

      request.headers.addAll({
        'accept': 'application/json',
      });

      final extension = path.extension(imageFile.path).toLowerCase();
      String mimeType;
      switch (extension) {
        case '.jpg':
        case '.jpeg':
          mimeType = 'image/jpeg';
          break;
        case '.png':
          mimeType = 'image/png';
          break;
        case '.pdf':
          mimeType = 'application/pdf';
          break;
        default:
          mimeType = 'application/octet-stream';
      }

      final fileName = path.basename(imageFile.path);
      var multipartFile = await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      );

      request.files.add(multipartFile);

      debugPrint('Enviando imagen para OCR: $fileName ($mimeType)');

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return jsonResponse;
      } else {
        debugPrint('Error en OCR: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error procesando imagen con OCR: $e');
      return null;
    }
  }
}
