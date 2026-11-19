// lib/models/campaign_models.dart

/// Modelo representativo de Campaña con serialización JSON bidireccional (fromJson / toJson)
class Campaign {
  final String id;
  final String nombre;
  final String? descripcion;
  final int canalId;
  final int estadoId;
  final String? programadaEn;
  final String? creadoEn;

  Campaign({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.canalId,
    required this.estadoId,
    this.programadaEn,
    this.creadoEn,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) => Campaign(
    id: (json['id'] ?? '').toString(),
    nombre: (json['nombre'] ?? '').toString(),
    descripcion: json['descripcion'] as String?,
    canalId: (json['canal_id'] as num?)?.toInt() ?? 5,
    estadoId: (json['estado_id'] as num?)?.toInt() ?? 2,
    programadaEn: json['programada_en'] as String?,
    creadoEn: json['creado_en'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'descripcion': descripcion,
    'canal_id': canalId,
    'estado_id': estadoId,
    'programada_en': programadaEn,
    'creado_en': creadoEn,
  };
}


class AudioSurvey {
  final String id;
  final SurveyTemplate plantilla;
  final String? destinatario;          // ← ya era nullable
  final String? creadoEn;              // ← por si tu endpoint lo manda
  final String? respondidoEn;

  AudioSurvey({
    required this.id,
    required this.plantilla,
    this.destinatario,
    this.creadoEn,
    this.respondidoEn,
  });

  factory AudioSurvey.fromJson(Map<String, dynamic> json) {
    final plantillaRaw = json['plantilla'];
    final plantilla = plantillaRaw is Map<String, dynamic>
        ? SurveyTemplate.fromJson(plantillaRaw)
        : SurveyTemplate(id: (json['id'] ?? '').toString(), nombre: 'Encuesta', preguntas: []);

    String? destinatario;
    final destRaw = json['destinatario'];
    if (destRaw is String) {
      destinatario = destRaw;
    } else if (destRaw is Map<String, dynamic>) {
      destinatario = (destRaw['nombre'] ?? destRaw['email'] ?? destRaw['telefono'])?.toString();
    }

    return AudioSurvey(
      id: (json['id'] ?? '').toString(),
      plantilla: plantilla,
      destinatario: destinatario,
      creadoEn: (json['creado_en'] ?? json['enviado_en'])?.toString(),
      respondidoEn: json['respondido_en']?.toString(),
    );
  }
}

class SurveyTemplate {
  final String id;
  final String nombre;
  final String? descripcion;           // ← nullable
  final List<Question> preguntas;

  SurveyTemplate({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.preguntas,
  });

  factory SurveyTemplate.fromJson(Map<String, dynamic> json) => SurveyTemplate(
    id          : (json['id'] ?? '').toString(),
    nombre      : (json['nombre'] ?? 'Plantilla').toString(),
    descripcion : json['descripcion'] as String?,
    preguntas   : (json['preguntas'] as List? ?? [])
        .map((q) => Question.fromJson(q as Map<String, dynamic>))
        .toList(),
  );
}

class Question {
  final String id;
  final int orden;
  final String texto;
  final int tipoPreguntaId;
  final bool obligatorio;
  final List<QuestionOption> opciones;

  Question({
    required this.id,
    required this.orden,
    required this.texto,
    required this.tipoPreguntaId,
    required this.obligatorio,
    required this.opciones,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: (json['id'] ?? '').toString(),
      orden: (json['orden'] as num?)?.toInt() ?? 1,
      texto: (json['texto'] ?? '').toString(),
      tipoPreguntaId: (json['tipo_pregunta_id'] ?? json['tipo_id'] as num?)?.toInt() ?? 1,
      obligatorio: json['obligatorio'] == true,
      opciones: (json['opciones'] as List? ?? [])
          .map((o) => QuestionOption.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuestionOption {
  final String id;
  final String? texto;                 // ← a veces nulo según tu BD
  final String? valor;                 // ← puede ser null / int

  QuestionOption({
    required this.id,
    this.texto,
    this.valor,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) => QuestionOption(
    id    : (json['id'] ?? '').toString(),
    texto : json['texto'] as String?,
    valor : json['valor']?.toString(),               // cast seguro
  );
}
class AudioTranscriptionResponse {
  final String entregaId;
  final String transcripcion;
  final List<dynamic> respuestas;
  final Map<String, dynamic> payloadEnviado;
  final Map<String, dynamic> respuestaBackend;
  final String status;
  final String? taskId;
  final bool isAsync;

  AudioTranscriptionResponse({
    required this.entregaId,
    required this.transcripcion,
    this.respuestas = const [],
    this.payloadEnviado = const {},
    this.respuestaBackend = const {},
    this.status = 'ok',
    this.taskId,
    this.isAsync = false,
  });

  factory AudioTranscriptionResponse.fromJson(Map<String, dynamic> json) {
    List<dynamic> parsedRespuestas = [];
    if (json['respuestas'] is List) {
      parsedRespuestas = json['respuestas'] as List<dynamic>;
    } else if (json['payload_enviado'] != null &&
        json['payload_enviado']['respuestas_preguntas'] is List) {
      parsedRespuestas =
          json['payload_enviado']['respuestas_preguntas'] as List<dynamic>;
    } else if (json['respuestas_preguntas'] is List) {
      parsedRespuestas = json['respuestas_preguntas'] as List<dynamic>;
    }

    final rawStatus = (json['status'] ?? json['estado'] ?? json['estado_transcripcion'] ?? 'ok').toString();
    final taskId = (json['task_id'] ?? json['job_id'] ?? json['id'])?.toString();
    final isAsync = (taskId != null && taskId.isNotEmpty) ||
        rawStatus == 'queued' ||
        rawStatus == 'processing' ||
        rawStatus == 'transcribing' ||
        rawStatus == 'pending' ||
        rawStatus == 'pendiente';

    return AudioTranscriptionResponse(
      entregaId: (json['entrega_id'] ?? '').toString(),
      transcripcion: (json['transcripcion'] ?? json['transcripcion_texto'] ?? json['texto_transcrito'] ?? '').toString(),
      respuestas: parsedRespuestas,
      payloadEnviado: json['payload_enviado'] is Map<String, dynamic>
          ? json['payload_enviado'] as Map<String, dynamic>
          : {},
      respuestaBackend: json['respuesta_backend'] is Map<String, dynamic>
          ? json['respuesta_backend'] as Map<String, dynamic>
          : {},
      status: rawStatus,
      taskId: taskId,
      isAsync: isAsync,
    );
  }
}
