import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/sync_queue_model.dart';
import '../models/campaign_models.dart';

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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Tabla de cola outbox para sincronización offline
    await db.execute('''
      CREATE TABLE sync_queue (
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

    // 2. Tabla de caché local de encuestas y plantillas
    await db.execute('''
      CREATE TABLE cached_surveys (
        id TEXT PRIMARY KEY,
        campaign_id TEXT NOT NULL,
        data_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
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
    )) ?? 0;

    final failedCount = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM sync_queue WHERE status = 'failed'",
    )) ?? 0;

    final syncedCount = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM sync_queue WHERE status = 'synced'",
    )) ?? 0;

    final todaySyncedCount = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM sync_queue WHERE status = 'synced' AND date(synced_at) = date('now')",
    )) ?? 0;

    final totalCount = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM sync_queue",
    )) ?? 0;

    return {
      'pending': pendingCount,
      'failed': failedCount,
      'synced': syncedCount,
      'today_synced': todaySyncedCount,
      'total': totalCount,
    };
  }

  // ────────────────────────── Métodos Caché Local ──────────────────────────

  Future<void> cacheSurveys(String campaignId, List<AudioSurvey> surveys) async {
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
            'plantilla': {
              'id': s.plantilla.id,
              'nombre': s.plantilla.nombre,
              'descripcion': s.plantilla.descripcion,
              'preguntas': s.plantilla.preguntas.map((q) => {
                'id': q.id,
                'orden': q.orden,
                'texto': q.texto,
                'tipo_pregunta_id': q.tipoPreguntaId,
                'obligatorio': q.obligatorio,
                'opciones': q.opciones.map((o) => {
                  'id': o.id,
                  'texto': o.texto,
                  'valor': o.valor,
                }).toList(),
              }).toList(),
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
    final db = await database;
    final maps = await db.query(
      'cached_surveys',
      where: 'campaign_id = ?',
      whereArgs: [campaignId],
    );

    return maps.map((m) {
      final data = jsonDecode(m['data_json'] as String) as Map<String, dynamic>;
      return AudioSurvey.fromJson(data);
    }).toList();
  }
}
