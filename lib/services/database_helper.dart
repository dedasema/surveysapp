import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/sync_queue_model.dart';
import '../models/campaign_models.dart';

/// Helper para base de datos local SQLite (sqflite).
/// Gestiona la cola outbox de sincronización, la caché local de campañas/encuestas para modo avión,
/// y la bitácora local de sincronización (sync_log).
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('surveys_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onOpen: (db) async {
        await _ensureTables(db);
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await _ensureTables(db);
  }

  Future<void> _ensureTables(Database db) async {
    // 1. Tabla de cola outbox para sincronización offline
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entrega_id TEXT UNIQUE NOT NULL,
        campaign_id TEXT,
        campaign_name TEXT,
        canal_id INTEGER NOT NULL,
        file_path TEXT,
        payload_json TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        error_message TEXT,
        created_at TEXT NOT NULL,
        synced_at TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 2. Tabla de caché local de encuestas y plantillas (Modo Avión)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_surveys (
        id TEXT PRIMARY KEY,
        campaign_id TEXT NOT NULL,
        data_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 3. Tabla de caché local de campañas asignadas al operador
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_campaigns (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        canal_id INTEGER,
        estado_id INTEGER,
        data_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 4. Bitácora local de sincronizaciones (sync_log) para métricas de efectividad
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL,
        cantidad_enviada INTEGER NOT NULL,
        cantidad_aceptada INTEGER NOT NULL,
        cantidad_rechazada INTEGER NOT NULL,
        error_message TEXT
      )
    ''');
  }

  // ────────────────────────── Métodos Sync Queue ──────────────────────────

  Future<int> insertQueueItem(SyncQueueItem item) async {
    final db = await database;
    return await db.insert(
      'sync_queue',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncQueueItem>> getPendingItems() async {
    final db = await database;
    final maps = await db.query(
      'sync_queue',
      where: 'status IN (?, ?)',
      whereArgs: ['pending', 'failed'],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => SyncQueueItem.fromMap(m)).toList();
  }

  Future<List<SyncQueueItem>> getAllQueueItems() async {
    final db = await database;
    final maps = await db.query(
      'sync_queue',
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => SyncQueueItem.fromMap(m)).toList();
  }

  Future<SyncQueueItem?> getItemByEntregaId(String entregaId) async {
    final db = await database;
    final maps = await db.query(
      'sync_queue',
      where: 'entrega_id = ?',
      whereArgs: [entregaId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return SyncQueueItem.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateItemStatus(
    int id,
    String status, {
    String? errorMessage,
    DateTime? syncedAt,
    int? retryCount,
    String? payloadJson,
  }) async {
    final db = await database;
    final values = <String, dynamic>{
      'status': status,
    };
    if (errorMessage != null) values['error_message'] = errorMessage;
    if (syncedAt != null) values['synced_at'] = syncedAt.toIso8601String();
    if (retryCount != null) values['retry_count'] = retryCount;
    if (payloadJson != null) values['payload_json'] = payloadJson;

    return await db.update(
      'sync_queue',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteQueueItem(int id) async {
    final db = await database;
    return await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, int>> getQueueCounts() async {
    final db = await database;
    final pendingCount = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM sync_queue WHERE status IN ('pending', 'syncing')",
        )) ??
        0;

    final failedCount = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM sync_queue WHERE status = 'failed'",
        )) ??
        0;

    final syncedCount = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM sync_queue WHERE status = 'synced'",
        )) ??
        0;

    final todaySyncedCount = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM sync_queue WHERE status = 'synced' AND date(synced_at) = date('now')",
        )) ??
        0;

    final totalCount = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM sync_queue",
        )) ??
        0;

    return {
      'pending': pendingCount,
      'failed': failedCount,
      'synced': syncedCount,
      'today_synced': todaySyncedCount,
      'total': totalCount,
    };
  }

  /// Verifica si la respuesta pendiente más antigua lleva más de 7 días sin enviarse
  Future<bool> hasPendingOlderThan7Days() async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT created_at FROM sync_queue 
        WHERE status IN ('pending', 'failed')
        ORDER BY created_at ASC LIMIT 1
      ''');
      if (result.isEmpty) return false;
      final createdAtStr = result.first['created_at'] as String?;
      if (createdAtStr == null) return false;
      final createdAt = DateTime.tryParse(createdAtStr);
      if (createdAt == null) return false;
      final difference = DateTime.now().difference(createdAt);
      return difference.inDays >= 7;
    } catch (e) {
      debugPrint('Error verificando antigüedad de pendientes: $e');
      return false;
    }
  }

  // ────────────────────────── Bitácora sync_log ──────────────────────────

  /// Registra un evento de sincronización en sync_log
  Future<int> insertSyncLog({
    required int enviada,
    required int aceptada,
    required int rechazada,
    String? errorMessage,
  }) async {
    try {
      final db = await database;
      return await db.insert('sync_log', {
        'fecha': DateTime.now().toIso8601String(),
        'cantidad_enviada': enviada,
        'cantidad_aceptada': aceptada,
        'cantidad_rechazada': rechazada,
        'error_message': errorMessage,
      });
    } catch (e) {
      debugPrint('Error insertando en sync_log: $e');
      return -1;
    }
  }

  /// Calcula el % de respuestas sincronizadas correctamente según sync_log
  Future<double> getSyncSuccessRate() async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT 
          SUM(cantidad_enviada) as total_enviadas,
          SUM(cantidad_aceptada) as total_aceptadas
        FROM sync_log
      ''');
      if (result.isEmpty) return 100.0;
      final enviadas = result.first['total_enviadas'] as int? ?? 0;
      final aceptadas = result.first['total_aceptadas'] as int? ?? 0;
      if (enviadas == 0) return 100.0;
      return (aceptadas / enviadas) * 100.0;
    } catch (e) {
      debugPrint('Error calculando tasa de éxito de sync_log: $e');
      return 100.0;
    }
  }

  // ────────────────────────── Métodos Caché Local (Modo Avión) ──────────────────────────

  Future<void> cacheCampaigns(List<Campaign> campaigns) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (final c in campaigns) {
      batch.insert(
        'cached_campaigns',
        {
          'id': c.id,
          'nombre': c.nombre,
          'descripcion': c.descripcion,
          'canal_id': c.canalId,
          'estado_id': c.estadoId,
          'data_json': jsonEncode(c.toJson()),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Campaign>> getCachedCampaigns() async {
    try {
      final db = await database;
      final maps = await db.query('cached_campaigns', orderBy: 'nombre ASC');
      return maps.map((m) {
        final data =
            jsonDecode(m['data_json'] as String) as Map<String, dynamic>;
        return Campaign.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error leyendo cached_campaigns: $e');
      return [];
    }
  }

  Future<void> cacheSurveys(
      String campaignId, List<AudioSurvey> surveys) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (final s in surveys) {
      batch.insert(
        'cached_surveys',
        {
          'id': s.id,
          'campaign_id': campaignId,
          'data_json': jsonEncode({
            'id': s.id,
            'destinatario': s.destinatario,
            'creado_en': s.creadoEn,
            'respondido_en': s.respondidoEn,
            'plantilla': {
              'id': s.plantilla.id,
              'nombre': s.plantilla.nombre,
              'descripcion': s.plantilla.descripcion,
              'preguntas': s.plantilla.preguntas
                  .map((q) => {
                        'id': q.id,
                        'orden': q.orden,
                        'texto': q.texto,
                        'tipo_pregunta_id': q.tipoPreguntaId,
                        'obligatorio': q.obligatorio,
                        'opciones': q.opciones
                            .map((o) => {
                                  'id': o.id,
                                  'texto': o.texto,
                                  'valor': o.valor,
                                })
                            .toList(),
                      })
                  .toList(),
            },
          }),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<AudioSurvey>> getCachedSurveys(String campaignId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'cached_surveys',
        where: 'campaign_id = ?',
        whereArgs: [campaignId],
      );

      return maps.map((m) {
        final data =
            jsonDecode(m['data_json'] as String) as Map<String, dynamic>;
        return AudioSurvey.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error leyendo cached_surveys: $e');
      return [];
    }
  }
}
