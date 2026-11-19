import 'dart:convert';

class SyncQueueItem {
  final int? id;
  final String entregaId;
  final String? campaignId;
  final String? campaignName;
  final int canalId; // 4 = Papel/OCR, 5 = Audio
  final String? filePath;
  final String?
      payloadJson; // JSON serializado de respuestas si ya fueron editadas/extraídas
  final String status; // 'pending', 'syncing', 'failed', 'synced'
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final int retryCount;

  SyncQueueItem({
    this.id,
    required this.entregaId,
    this.campaignId,
    this.campaignName,
    required this.canalId,
    this.filePath,
    this.payloadJson,
    this.status = 'pending',
    this.errorMessage,
    required this.createdAt,
    this.syncedAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entrega_id': entregaId,
      'campaign_id': campaignId,
      'campaign_name': campaignName,
      'canal_id': canalId,
      'file_path': filePath,
      'payload_json': payloadJson,
      'status': status,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'retry_count': retryCount,
    };
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] as int?,
      entregaId: map['entrega_id'] as String,
      campaignId: map['campaign_id'] as String?,
      campaignName: map['campaign_name'] as String?,
      canalId: map['canal_id'] as int,
      filePath: map['file_path'] as String?,
      payloadJson: map['payload_json'] as String?,
      status: map['status'] as String? ?? 'pending',
      errorMessage: map['error_message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
      retryCount: map['retry_count'] as int? ?? 0,
    );
  }

  SyncQueueItem copyWith({
    int? id,
    String? entregaId,
    String? campaignId,
    String? campaignName,
    int? canalId,
    String? filePath,
    String? payloadJson,
    String? status,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? syncedAt,
    int? retryCount,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      entregaId: entregaId ?? this.entregaId,
      campaignId: campaignId ?? this.campaignId,
      campaignName: campaignName ?? this.campaignName,
      canalId: canalId ?? this.canalId,
      filePath: filePath ?? this.filePath,
      payloadJson: payloadJson ?? this.payloadJson,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic>? get parsedPayload {
    if (payloadJson == null || payloadJson!.isEmpty) return null;
    try {
      return jsonDecode(payloadJson!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String get canalLabel {
    switch (canalId) {
      case 4:
        return 'Papel (OCR)';
      case 5:
        return 'Audio (Voz)';
      default:
        return 'Canal $canalId';
    }
  }
}
