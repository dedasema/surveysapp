import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/campaign_models.dart';
import '../services/audio_service.dart';
import '../services/offline_sync_service.dart';

class SurveyReviewScreen extends StatefulWidget {
  final String entregaId;
  final SurveyTemplate plantilla;
  final List<dynamic> initialRespuestas;
  final String? campaignId;
  final String? campaignName;
  final int canalId; // 4 = Papel/OCR, 5 = Audio
  final String? localFilePath;

  const SurveyReviewScreen({
    super.key,
    required this.entregaId,
    required this.plantilla,
    this.initialRespuestas = const [],
    this.campaignId,
    this.campaignName,
    required this.canalId,
    this.localFilePath,
  });

  @override
  State<SurveyReviewScreen> createState() => _SurveyReviewScreenState();
}

class _SurveyReviewScreenState extends State<SurveyReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String?> _selectedSingleOption = {};
  final Map<String, Set<String>> _selectedMultiOptions = {};

  @override
  void initState() {
    super.initState();
    _initializeFormValues();
  }

  void _initializeFormValues() {
    // Inicializar mapas para cada pregunta de la plantilla
    for (final pregunta in widget.plantilla.preguntas) {
      _textControllers[pregunta.id] = TextEditingController();
      _selectedSingleOption[pregunta.id] = null;
      _selectedMultiOptions[pregunta.id] = {};
    }

    // Pre-llenar con las respuestas detectadas por IA (initialRespuestas)
    for (final r in widget.initialRespuestas) {
      if (r is! Map) continue;
      final qid = (r['pregunta_id'] ?? r['id'])?.toString();
      if (qid == null || !_textControllers.containsKey(qid)) continue;

      if (r['texto'] != null) {
        _textControllers[qid]!.text = r['texto'].toString();
      } else if (r['numero'] != null) {
        _textControllers[qid]!.text = r['numero'].toString();
      }

      if (r['opcion_id'] != null) {
        _selectedSingleOption[qid] = r['opcion_id'].toString();
      }

      if (r['opciones_ids'] != null && r['opciones_ids'] is List) {
        for (final oid in r['opciones_ids']) {
          _selectedMultiOptions[qid]!.add(oid.toString());
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _buildPayload() {
    final List<Map<String, dynamic>> filas = [];

    for (final pregunta in widget.plantilla.preguntas) {
      final qid = pregunta.id;

      if (pregunta.tipoPreguntaId == 1) {
        // Texto
        final txt = _textControllers[qid]?.text.trim();
        if (txt != null && txt.isNotEmpty) {
          filas.add({'pregunta_id': qid, 'texto': txt});
        }
      } else if (pregunta.tipoPreguntaId == 2) {
        // Número / Escala
        final val = _textControllers[qid]?.text.trim();
        if (val != null && val.isNotEmpty) {
          final numVal = num.tryParse(val);
          filas.add({
            'pregunta_id': qid,
            'numero': numVal ?? val,
          });
        }
      } else if (pregunta.tipoPreguntaId == 3) {
        // Opción única
        final selected = _selectedSingleOption[qid];
        if (selected != null && selected.isNotEmpty) {
          filas.add({'pregunta_id': qid, 'opcion_id': selected});
        }
      } else if (pregunta.tipoPreguntaId == 4) {
        // Opción múltiple
        final selectedSet = _selectedMultiOptions[qid] ?? {};
        for (final oid in selectedSet) {
          filas.add({'pregunta_id': qid, 'opcion_id': oid});
        }
      }
    }

    return {'respuestas_preguntas': filas};
  }

  Future<void> _submitSurvey() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final payload = _buildPayload();
    final isOnline = await OfflineSyncService.instance.isOnline();

    if (!isOnline) {
      // Guardar en cola offline de inmediato
      await _saveOffline(payload);
      return;
    }

    try {
      final baseUrl = AudioService.baseUrl;
      final uri = Uri.parse('$baseUrl/public/entregas/${widget.entregaId}/respuestas');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'accept': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          _showSuccessDialog(
            title: '¡Encuesta Guardada!',
            message: 'Las respuestas fueron sincronizadas exitosamente en el servidor.',
            isOffline: false,
          );
        }
      } else {
        // Si falló el servidor, asegurar persistencia encolando offline
        await _saveOffline(payload);
      }
    } catch (e) {
      await _saveOffline(payload);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _saveOffline(Map<String, dynamic> payload) async {
    if (widget.canalId == 5) {
      await OfflineSyncService.instance.enqueueAudioSurvey(
        entregaId: widget.entregaId,
        campaignId: widget.campaignId,
        campaignName: widget.campaignName,
        filePath: widget.localFilePath ?? '',
        payload: payload,
      );
    } else {
      await OfflineSyncService.instance.enqueueOCRSurvey(
        entregaId: widget.entregaId,
        campaignId: widget.campaignId,
        campaignName: widget.campaignName,
        filePath: widget.localFilePath ?? '',
        payload: payload,
      );
    }

    if (mounted) {
      _showSuccessDialog(
        title: 'Guardado Offline',
        message: 'Sin conexión estable. La encuesta quedó guardada en el dispositivo y se sincronizará automáticamente al recuperar señal.',
        isOffline: true,
      );
    }
  }

  void _showSuccessDialog({
    required String title,
    required String message,
    required bool isOffline,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isOffline ? Icons.cloud_off : Icons.check_circle,
              color: isOffline ? Colors.orange : Colors.green,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cerrar diálogo
              Navigator.of(context).pop(); // Volver a la pantalla anterior
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar y Validar'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Banner informativo superior
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFE3F2FD),
              child: Row(
                children: [
                  const Icon(Icons.verified_user, color: Color(0xFF1565C0)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.plantilla.nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Revisa y edita las respuestas extraídas por IA antes de confirmar.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Lista de preguntas interactivas
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.plantilla.preguntas.length,
                itemBuilder: (context, index) {
                  final pregunta = widget.plantilla.preguntas[index];
                  return _buildQuestionCard(pregunta, index + 1);
                },
              ),
            ),

            // Barra inferior de confirmación
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitSurvey,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSubmitting ? 'Guardando...' : 'Confirmar y Guardar Encuesta',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question pregunta, int questionNumber) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFF1565C0),
                  child: Text(
                    '$questionNumber',
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pregunta.texto,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildInputForQuestion(pregunta),
          ],
        ),
      ),
    );
  }

  Widget _buildInputForQuestion(Question pregunta) {
    final qid = pregunta.id;

    switch (pregunta.tipoPreguntaId) {
      case 1:
        // Texto libre
        return TextFormField(
          controller: _textControllers[qid],
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Ingresa o edita la respuesta...',
            filled: true,
            fillColor: Colors.grey[50],
          ),
        );

      case 2:
        // Número / Escala
        return TextFormField(
          controller: _textControllers[qid],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Ingresa un valor numérico...',
            filled: true,
            fillColor: Colors.grey[50],
          ),
        );

      case 3:
        // Opción única
        return Column(
          children: pregunta.opciones.map((opcion) {
            return RadioListTile<String>(
              title: Text(opcion.texto ?? 'Opción'),
              value: opcion.id,
              groupValue: _selectedSingleOption[qid],
              activeColor: const Color(0xFF1565C0),
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  _selectedSingleOption[qid] = val;
                });
              },
            );
          }).toList(),
        );

      case 4:
        // Opción múltiple
        return Column(
          children: pregunta.opciones.map((opcion) {
            final isChecked = _selectedMultiOptions[qid]?.contains(opcion.id) ?? false;
            return CheckboxListTile(
              title: Text(opcion.texto ?? 'Opción'),
              value: isChecked,
              activeColor: const Color(0xFF1565C0),
              contentPadding: EdgeInsets.zero,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedMultiOptions[qid]?.add(opcion.id);
                  } else {
                    _selectedMultiOptions[qid]?.remove(opcion.id);
                  }
                });
              },
            );
          }).toList(),
        );

      default:
        return TextFormField(
          controller: _textControllers[qid],
          decoration: const InputDecoration(hintText: 'Respuesta...'),
        );
    }
  }
}
