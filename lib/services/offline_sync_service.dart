import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/sync_queue_model.dart';
import 'database_helper.dart';
import 'audio_service.dart';
import 'ocr_service.dart';
import 'notification_service.dart';

/// Servicio de sincronización en segundo plano con soporte offline-first,
/// generación de UUID v4 de cliente estable, reintentos con backoff exponencial,
/// bitácora sync_log e idempotencia ante reintentos.
class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._init();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final Connectivity _connectivity = Connectivity();
  static const _uuid = Uuid();

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isSyncing = false;
  final _countsController = StreamController<Map<String, int>>.broadcast();

  Stream<Map<String, int>> get countsStream => _countsController.stream;

  OfflineSyncService._init() {
    _initConnectivityListener();
    refreshCounts();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        // Conexión restablecida: dispara sincronización automática por lotes
        syncPendingQueue();
      }
    });
  }

  /// Genera un UUID v4 de cliente estándar para garantizar identificación única y estable
  static String generateClientUuid() => _uuid.v4();

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<void> refreshCounts() async {
    final counts = await _db.getQueueCounts();
    _countsController.add(counts);
  }

  Future<bool> hasPendingOlderThan7Days() async {
    return await _db.hasPendingOlderThan7Days();
  }

  Future<double> getSyncSuccessRate() async {
    return await _db.getSyncSuccessRate();
  }

  // ────────────────────────── Encolado de Items ──────────────────────────

  Future<String> enqueueAudioSurvey({
    String? entregaId,
    String? campaignId,
    String? campaignName,
    required String filePath,
    Map<String, dynamic>? payload,
  }) async {
    // Si no tiene entregaId o no es UUID válido, generar UUID v4 estable de cliente
    final clientUuid = (entregaId != null && entregaId.isNotEmpty)
        ? entregaId
        : generateClientUuid();

    final item = SyncQueueItem(
      entregaId: clientUuid,
      campaignId: campaignId,
      campaignName: campaignName,
      canalId: 5,
      filePath: filePath,
      payloadJson: payload != null ? jsonEncode(payload) : null,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _db.insertQueueItem(item);
    await refreshCounts();

    if (await isOnline()) {
      unawaited(syncPendingQueue());
    }

    return clientUuid;
  }

  Future<String> enqueueOCRSurvey({
    String? entregaId,
    String? campaignId,
    String? campaignName,
    required String filePath,
    Map<String, dynamic>? payload,
  }) async {
    final clientUuid = (entregaId != null && entregaId.isNotEmpty)
        ? entregaId
        : generateClientUuid();

    final item = SyncQueueItem(
      entregaId: clientUuid,
      campaignId: campaignId,
      campaignName: campaignName,
      canalId: 4,
      filePath: filePath,
      payloadJson: payload != null ? jsonEncode(payload) : null,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _db.insertQueueItem(item);
    await refreshCounts();

    if (await isOnline()) {
      unawaited(syncPendingQueue());
    }

    return clientUuid;
  }

  // ────────────────────────── Motor de Sincronización ──────────────────────────

  /// Sincroniza las respuestas pendientes por lotes con reintentos y backoff exponencial
  Future<void> syncPendingQueue() async {
    if (_isSyncing) return;
    if (!await isOnline()) return;

    _isSyncing = true;
    int successCount = 0;
    int errorCount = 0;
    String? lastError;

    try {
      final pendingItems = await _db.getPendingItems();
      final now = DateTime.now();

      // Procesar en lotes de hasta 10 elementos respetando backoff exponencial
      final batch = pendingItems.take(10).toList();

      for (final item in batch) {
        // Cálculo de espera exponencial creciente (backoff): 2^reintentos * 5 seg (máx 5 min)
        if (item.retryCount > 0) {
          final backoffSeconds = min(300, pow(2, item.retryCount).toInt() * 5);
          final elapsedSeconds = now.difference(item.createdAt).inSeconds;
          if (elapsedSeconds < backoffSeconds) {
            // Aún está dentro del periodo de espera exponencial
            continue;
          }
        }

        final success = await _processItem(item);
        if (success) {
          successCount++;
        } else {
          errorCount++;
          lastError = item.errorMessage;
        }
      }

      // Registro en bitácora sync_log para métricas
      if (batch.isNotEmpty) {
        await _db.insertSyncLog(
          enviada: batch.length,
          aceptada: successCount,
          rechazada: errorCount,
          errorMessage: lastError,
        );
      }

      if (successCount > 0 || errorCount > 0) {
        await NotificationService.instance.notifyOfflineSync(
          syncedCount: successCount,
          failedCount: errorCount,
        );
      }
    } catch (e) {
      debugPrint('Error en syncPendingQueue: $e');
    } finally {
      _isSyncing = false;
      await refreshCounts();
    }
  }

  Future<bool> _processItem(SyncQueueItem item) async {
    if (item.id == null) return false;

    await _db.updateItemStatus(item.id!, 'syncing');

    try {
      final baseUrl = AudioService.baseUrl;

      // Caso 1: Respuestas estructuradas JSON validadas por el operador
      if (item.payloadJson != null && item.payloadJson!.isNotEmpty) {
        final uri = Uri.parse('$baseUrl/public/entregas/${item.entregaId}/respuestas');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json', 'accept': 'application/json'},
          body: item.payloadJson,
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 || response.statusCode == 201) {
          await _markItemSuccess(item);
          return true;
        } else if (response.statusCode == 400 &&
            response.body.toLowerCase().contains('ya ha sido respondida')) {
          // Idempotencia: el servidor ya guardó esta respuesta previamente
          debugPrint('Idempotencia detectada para ${item.entregaId}: ya respondida en el backend.');
          await _markItemSuccess(item);
          return true;
        } else {
          throw Exception('Backend HTTP ${response.statusCode}: ${response.body}');
        }
      }

      // Caso 2: Audio sin procesar (WAV)
      if (item.canalId == 5 && item.filePath != null) {
        final file = File(item.filePath!);
        if (!await file.exists()) {
          throw Exception('Archivo de audio local no encontrado: ${item.filePath}');
        }

        final audioService = AudioService();
        await audioService.transcribeAudio(item.entregaId, file);
        await _markItemSuccess(item);
        return true;
      }

      // Caso 3: Imagen OCR sin procesar
      if (item.canalId == 4 && item.filePath != null) {
        final file = File(item.filePath!);
        if (!await file.exists()) {
          throw Exception('Archivo de imagen local no encontrado: ${item.filePath}');
        }

        final ocrService = OCRService();
        final result = await ocrService.processImage(file, entregaId: item.entregaId);
        if (result != null) {
          await _markItemSuccess(item);
          return true;
        } else {
          throw Exception('Error al procesar OCR con el backend');
        }
      }

      throw Exception('Elemento de cola sin archivo ni respuestas válidas');
    } catch (e) {
      final nextRetry = item.retryCount + 1;
      await _db.updateItemStatus(
        item.id!,
        'failed',
        errorMessage: e.toString(),
        retryCount: nextRetry,
      );
      return false;
    }
  }

  Future<void> _markItemSuccess(SyncQueueItem item) async {
    await _db.updateItemStatus(
      item.id!,
      'synced',
      syncedAt: DateTime.now(),
      errorMessage: null,
    );

    // Limpieza segura del archivo local en disco
    if (item.filePath != null) {
      try {
        final f = File(item.filePath!);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
  }

  Future<void> retryItem(int id) async {
    final items = await _db.getAllQueueItems();
    final item = items.firstWhere((i) => i.id == id, orElse: () => throw Exception('Item no encontrado'));
    await _processItem(item);
    await refreshCounts();
  }

  Future<void> deleteItem(int id) async {
    await _db.deleteQueueItem(id);
    await refreshCounts();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _countsController.close();
  }
}
