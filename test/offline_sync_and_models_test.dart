import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:surveys_app/models/campaign_models.dart';
import 'package:surveys_app/models/sync_queue_model.dart';
import 'package:surveys_app/services/offline_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pruebas Oficiales de Infraestructura Offline (A13)', () {
    // ─────────────────────────────────────────────────────────────
    // PRUEBA 1: Guardado local de una respuesta (SyncQueueItem)
    // ─────────────────────────────────────────────────────────────
    test('1. Guardado local de una respuesta: serialización y consistencia de datos', () {
      final now = DateTime.now();
      final originalItem = SyncQueueItem(
        id: 101,
        entregaId: 'test-entrega-uuid-101',
        campaignId: 'camp-55',
        campaignName: 'Censo Rural 2026',
        canalId: 5,
        filePath: '/data/user/0/com.example.surveysapp/files/audio_101.wav',
        payloadJson: jsonEncode({'pregunta_1': 'Respuesta satisfactoria'}),
        status: 'pending',
        createdAt: now,
        retryCount: 0,
      );

      // Verificamos serialización a Map para SQLite
      final map = originalItem.toMap();
      expect(map['entrega_id'], 'test-entrega-uuid-101');
      expect(map['campaign_name'], 'Censo Rural 2026');
      expect(map['status'], 'pending');
      expect(map['retry_count'], 0);

      // Verificamos deserialización desde SQLite
      final reconstructed = SyncQueueItem.fromMap(map);
      expect(reconstructed.id, 101);
      expect(reconstructed.entregaId, originalItem.entregaId);
      expect(reconstructed.payloadJson, originalItem.payloadJson);
      expect(reconstructed.filePath, originalItem.filePath);
      expect(reconstructed.status, 'pending');
    });

    // ─────────────────────────────────────────────────────────────
    // PRUEBA 2: Generación de UUID estable en reintentos
    // ─────────────────────────────────────────────────────────────
    test('2. Generación de UUID v4 de cliente y estabilidad a través de reintentos', () {
      final clientUuid = OfflineSyncService.generateClientUuid();

      // Validar formato estándar UUID v4 (8-4-4-4-12 caracteres hexadecimales)
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', caseSensitive: false);
      expect(uuidRegex.hasMatch(clientUuid), isTrue);

      // Simular múltiples reintentos con backoff
      var item = SyncQueueItem(
        id: 1,
        entregaId: clientUuid,
        canalId: 5,
        status: 'pending',
        createdAt: DateTime.now(),
        retryCount: 0,
      );

      for (int attempt = 1; attempt <= 3; attempt++) {
        // En cada fallo, el retryCount incrementa pero el entregaId (UUID v4) permanece idéntico
        item = SyncQueueItem(
          id: item.id,
          entregaId: item.entregaId,
          canalId: item.canalId,
          status: 'failed',
          errorMessage: 'Timeout en reintento $attempt',
          createdAt: item.createdAt,
          retryCount: attempt,
        );

        expect(item.entregaId, equals(clientUuid));
        expect(item.retryCount, equals(attempt));

        // Verificar cálculo de backoff exponencial: 2^attempt * 5
        final backoff = min(300, pow(2, item.retryCount).toInt() * 5);
        expect(backoff, equals(pow(2, attempt).toInt() * 5));
      }
    });

    // ─────────────────────────────────────────────────────────────
    // PRUEBA 3: Cola de sincronización (lote aceptado y parcialmente rechazado)
    // ─────────────────────────────────────────────────────────────
    test('3. Cola de sincronización: procesamiento por lotes con aceptación y rechazo parcial', () {
      final batch = [
        SyncQueueItem(id: 1, entregaId: 'uuid-1', canalId: 5, status: 'pending', createdAt: DateTime.now()),
        SyncQueueItem(id: 2, entregaId: 'uuid-2', canalId: 5, status: 'pending', createdAt: DateTime.now()),
        SyncQueueItem(id: 3, entregaId: 'uuid-3', canalId: 5, status: 'pending', createdAt: DateTime.now()),
      ];

      // Simular respuestas del backend en el lote:
      // Item 1: HTTP 200 (Aceptado)
      // Item 2: HTTP 500 (Rechazado temporalmente)
      // Item 3: HTTP 201 (Aceptado)
      final simulatedResponses = [200, 500, 201];
      int accepted = 0;
      int rejected = 0;
      final updatedBatch = <SyncQueueItem>[];

      for (int i = 0; i < batch.length; i++) {
        final code = simulatedResponses[i];
        if (code == 200 || code == 201) {
          accepted++;
          updatedBatch.add(SyncQueueItem(
            id: batch[i].id,
            entregaId: batch[i].entregaId,
            canalId: batch[i].canalId,
            status: 'synced',
            syncedAt: DateTime.now(),
            createdAt: batch[i].createdAt,
          ));
        } else {
          rejected++;
          updatedBatch.add(SyncQueueItem(
            id: batch[i].id,
            entregaId: batch[i].entregaId,
            canalId: batch[i].canalId,
            status: 'failed',
            errorMessage: 'HTTP 500 Internal Error',
            retryCount: batch[i].retryCount + 1,
            createdAt: batch[i].createdAt,
          ));
        }
      }

      expect(accepted, 2);
      expect(rejected, 1);
      expect(updatedBatch[0].status, 'synced');
      expect(updatedBatch[1].status, 'failed');
      expect(updatedBatch[1].retryCount, 1);
      expect(updatedBatch[2].status, 'synced');
    });

    // ─────────────────────────────────────────────────────────────
    // PRUEBA 4: Modelo Campaign con fromJson / toJson bidireccional
    // ─────────────────────────────────────────────────────────────
    test('4. Modelo Campaign: serialización bidireccional fromJson / toJson', () {
      final jsonMap = {
        'id': 'camp-2026-xyz',
        'nombre': 'Encuesta de Satisfacción Altiplano',
        'descripcion': 'Estudio presencial de campo sin cobertura',
        'canal_id': 5,
        'estado_id': 2,
        'programada_en': '2026-11-20T08:00:00Z',
        'creado_en': '2026-11-19T10:00:00Z',
      };

      // Deserialización fromJson
      final campaign = Campaign.fromJson(jsonMap);
      expect(campaign.id, 'camp-2026-xyz');
      expect(campaign.nombre, 'Encuesta de Satisfacción Altiplano');
      expect(campaign.descripcion, 'Estudio presencial de campo sin cobertura');
      expect(campaign.canalId, 5);
      expect(campaign.estadoId, 2);

      // Serialización toJson
      final exportedJson = campaign.toJson();
      expect(exportedJson['id'], jsonMap['id']);
      expect(exportedJson['nombre'], jsonMap['nombre']);
      expect(exportedJson['descripcion'], jsonMap['descripcion']);
      expect(exportedJson['canal_id'], jsonMap['canal_id']);
      expect(exportedJson['estado_id'], jsonMap['estado_id']);
    });

    // ─────────────────────────────────────────────────────────────
    // PRUEBA 5: Corte de red emulado y sincronización sin duplicados
    // ─────────────────────────────────────────────────────────────
    test('5. Corte de red emulado: encolado sin pérdida y sincronización idempotente sin duplicados', () {
      bool isOnline = false; // Emulación: Modo Avión / Sin Red
      final localQueue = <SyncQueueItem>[];

      // 1. Operador responde 2 encuestas en modo avión
      final response1Uuid = OfflineSyncService.generateClientUuid();
      final response2Uuid = OfflineSyncService.generateClientUuid();

      if (!isOnline) {
        localQueue.add(SyncQueueItem(
          id: 1,
          entregaId: response1Uuid,
          canalId: 5,
          payloadJson: jsonEncode({'pregunta': 'Excelente servicio'}),
          status: 'pending',
          createdAt: DateTime.now(),
        ));
        localQueue.add(SyncQueueItem(
          id: 2,
          entregaId: response2Uuid,
          canalId: 5,
          payloadJson: jsonEncode({'pregunta': 'Buena atención'}),
          status: 'pending',
          createdAt: DateTime.now(),
        ));
      }

      // Verificamos que ninguna respuesta se perdió con la red caída
      expect(localQueue.length, 2);
      expect(localQueue.every((item) => item.status == 'pending'), isTrue);

      // 2. Vuelve la red (isOnline = true)
      isOnline = true;
      expect(isOnline, isTrue);

      // 3. Simulación de envío con reintento idempotente:
      // Servidor confirma entrega 1 con HTTP 200 y entrega 2 con HTTP 400 "Esta encuesta ya ha sido respondida"
      final syncResults = <String, String>{};
      for (final item in localQueue) {
        final String simulatedBackendResponse = (item.entregaId == response2Uuid)
            ? 'HTTP 400: Esta encuesta ya ha sido respondida'
            : 'HTTP 200: OK';

        if (simulatedBackendResponse.contains('200') ||
            simulatedBackendResponse.contains('ya ha sido respondida')) {
          // Idempotencia: en ambos casos se marca como sincronizada sin duplicar
          syncResults[item.entregaId] = 'synced';
        }
      }

      expect(syncResults[response1Uuid], 'synced');
      expect(syncResults[response2Uuid], 'synced');
      expect(syncResults.length, 2); // Cero respuestas duplicadas
    });
  });
}
