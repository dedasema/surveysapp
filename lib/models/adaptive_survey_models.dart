import 'campaign_models.dart';

class AdaptiveSession {
  final String sesionId;
  final String entregaId;
  final String? campanaId;
  final Question? preguntaActual;
  final int pasoActual;
  final double progreso;
  final bool completada;
  final String? mensajeFinal;

  AdaptiveSession({
    required this.sesionId,
    required this.entregaId,
    this.campanaId,
    this.preguntaActual,
    this.pasoActual = 1,
    this.progreso = 0.0,
    this.completada = false,
    this.mensajeFinal,
  });

  factory AdaptiveSession.fromJson(Map<String, dynamic> json,
      {required String fallbackEntregaId}) {
    Question? pregunta;
    if (json['pregunta_actual'] != null &&
        json['pregunta_actual'] is Map<String, dynamic>) {
      pregunta = Question.fromJson(json['pregunta_actual']);
    } else if (json['siguiente_pregunta'] != null &&
        json['siguiente_pregunta'] is Map<String, dynamic>) {
      pregunta = Question.fromJson(json['siguiente_pregunta']);
    } else if (json['pregunta'] != null &&
        json['pregunta'] is Map<String, dynamic>) {
      pregunta = Question.fromJson(json['pregunta']);
    }

    return AdaptiveSession(
      sesionId: (json['sesion_id'] ?? json['session_id'] ?? fallbackEntregaId)
          .toString(),
      entregaId: (json['entrega_id'] ?? fallbackEntregaId).toString(),
      campanaId: json['campana_id']?.toString(),
      preguntaActual: pregunta,
      pasoActual:
          json['paso_actual'] as int? ?? json['indice_paso'] as int? ?? 1,
      progreso: (json['progreso'] as num?)?.toDouble() ?? 0.0,
      completada: json['completada'] as bool? ??
          json['es_final'] as bool? ??
          (pregunta == null),
      mensajeFinal:
          json['mensaje_final'] as String? ?? json['mensaje'] as String?,
    );
  }
}
