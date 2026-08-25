import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../models/sync_queue_model.dart';
import 'database_helper.dart';
import 'audio_service.dart';
import 'ocr_service.dart';

class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._init();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final Connectivity _connectivity = Connectivity();
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
        // Conexión restablecida: dispara sincronización automática
        syncPendingQueue();
      }
    });
  }

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<void> refreshCounts() async {
    final counts = await _db.getQueueCounts();
    _countsController.add(counts);
  }

  // ────────────────────────── Encolado de Items ──────────────────────────

  Future<void> enqueueAudioSurvey({
    required String entregaId,
    String? campaignId,
    String? campaignName,
    required String filePath,
    Map<String, dynamic>? payload,
  }) async {
    final item = SyncQueueItem(
      entregaId: entregaId,
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

    // Intentar sincronizar de inmediato si hay internet
    if (await isOnline()) {
      syncPendingQueue();
    }
  }

  Future<void> enqueueOCRSurvey({
    required String entregaId,
    String? campaignId,
    String? campaignName,
    required String filePath,
    Map<String, dynamic>? payload,
  }) async {
    final item = SyncQueueItem(
      entregaId: entregaId,
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

    // Intentar sincronizar de inmediato si hay internet
    if (await isOnline()) {
      syncPendingQueue();
    }
  }

  // ────────────────────────── Motor de Sincronización ──────────────────────────

  Future<void> syncPendingQueue() async {
    if (_isSyncing) return;
    if (!await isOnline()) return;

    _isSyncing = true;
    try {
      final pendingItems = await _db.getPendingItems();

      for (final item in pendingItems) {
        await _processItem(item);
      }
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

      // Caso 1: El operador ya validó las respuestas en la UI (tenemos payload JSON)
      if (item.payloadJson != null && item.payloadJson!.isNotEmpty) {
        final uri = Uri.parse('$baseUrl/public/entregas/${item.entregaId}/respuestas');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json', 'accept': 'application/json'},
          body: item.payloadJson,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await _markItemSuccess(item);
          return true;
        } else if (response.statusCode == 400 &&
            response.body.toLowerCase().contains('ya ha sido respondida')) {
          // Idempotencia: si ya estaba respondida en el servidor, marcar como completada
          await _markItemSuccess(item);
          return true;
        } else {
          throw Exception('Backend HTTP ${response.statusCode}: ${response.body}');
        }
      }

      // Caso 2: Se guardó el archivo sin procesar (Audio)
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

      // Caso 3: Se guardó la imagen sin procesar (OCR Papel)
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
      await _db.updateItemStatus(
        item.id!,
        'failed',
        errorMessage: e.toString(),
        retryCount: item.retryCount + 1,
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
      } catch (_) {
        // Ignorar fallos menores de borrado
      }
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
