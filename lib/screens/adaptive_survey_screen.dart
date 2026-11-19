import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/campaign_models.dart';
import '../models/adaptive_survey_models.dart';
import '../services/audio_service.dart';
import '../services/offline_sync_service.dart';

class AdaptiveSurveyScreen extends StatefulWidget {
  final String entregaId;
  final String? campaignId;
  final String? campaignName;
  final SurveyTemplate? plantillaFallback;

  const AdaptiveSurveyScreen({
    super.key,
    required this.entregaId,
    this.campaignId,
    this.campaignName,
    this.plantillaFallback,
  });

  @override
  State<AdaptiveSurveyScreen> createState() => _AdaptiveSurveyScreenState();
}

class _AdaptiveSurveyScreenState extends State<AdaptiveSurveyScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSubmittingStep = false;
  String? _errorMessage;

  AdaptiveSession? _session;
  int _currentStepIndex = 0;
  List<Question> _fallbackQuestions = [];

  // Controladores de respuesta para la pregunta actual
  final TextEditingController _textController = TextEditingController();
  String? _selectedSingleOption;
  final Set<String> _selectedMultiOptions = {};

  final List<Map<String, dynamic>> _respuestasAcumuladas = [];

  late AnimationController _transitionController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeInOut,
    );

    if (widget.plantillaFallback != null) {
      _fallbackQuestions = widget.plantillaFallback!.preguntas;
    }

    _initAdaptiveSession();
  }

  @override
  void dispose() {
    _textController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  Future<void> _initAdaptiveSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isOnline = await OfflineSyncService.instance.isOnline();

    if (!isOnline || _fallbackQuestions.isNotEmpty) {
      // Modo adaptativo local / fallback
      if (_fallbackQuestions.isNotEmpty) {
        setState(() {
          _session = AdaptiveSession(
            sesionId: 'local_${widget.entregaId}',
            entregaId: widget.entregaId,
            campanaId: widget.campaignId,
            preguntaActual: _fallbackQuestions.first,
            pasoActual: 1,
            progreso: 1.0 / _fallbackQuestions.length,
            completada: false,
          );
          _isLoading = false;
        });
        _transitionController.forward();
        return;
      }
    }

    // Consultar al backend para iniciar sesión adaptativa
    try {
      final baseUrl = AudioService.baseUrl;
      final uri = Uri.parse(
          '$baseUrl/public/entregas/${widget.entregaId}/adaptativa/iniciar');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json'
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          _session = AdaptiveSession.fromJson(data,
              fallbackEntregaId: widget.entregaId);
          _isLoading = false;
        });
        _transitionController.forward();
      } else {
        // Fallback a preguntas locales si el endpoint devuelve 404
        _useLocalFallback();
      }
    } catch (e) {
      _useLocalFallback();
    }
  }

  void _useLocalFallback() {
    if (_fallbackQuestions.isNotEmpty) {
      setState(() {
        _session = AdaptiveSession(
          sesionId: 'local_${widget.entregaId}',
          entregaId: widget.entregaId,
          campanaId: widget.campaignId,
          preguntaActual: _fallbackQuestions.first,
          pasoActual: 1,
          progreso: 1.0 / _fallbackQuestions.length,
          completada: false,
        );
        _isLoading = false;
      });
      _transitionController.forward();
    } else {
      setState(() {
        _errorMessage = 'No se pudo inicializar la encuesta adaptativa.';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _collectCurrentAnswer() {
    final pregunta = _session?.preguntaActual;
    if (pregunta == null) return {};

    final qid = pregunta.id;

    if (pregunta.tipoPreguntaId == 1) {
      // Texto
      return {'pregunta_id': qid, 'texto': _textController.text.trim()};
    } else if (pregunta.tipoPreguntaId == 2) {
      // Número
      final val = num.tryParse(_textController.text.trim());
      return {'pregunta_id': qid, 'numero': val ?? _textController.text.trim()};
    } else if (pregunta.tipoPreguntaId == 3) {
      // Opción única
      return {'pregunta_id': qid, 'opcion_id': _selectedSingleOption};
    } else if (pregunta.tipoPreguntaId == 4) {
      // Opción múltiple
      return {
        'pregunta_id': qid,
        'opciones_ids': _selectedMultiOptions.toList(),
      };
    }

    return {'pregunta_id': qid, 'texto': _textController.text.trim()};
  }

  bool _validateCurrentAnswer() {
    final pregunta = _session?.preguntaActual;
    if (pregunta == null) return true;

    if (!pregunta.obligatorio) return true;

    if (pregunta.tipoPreguntaId == 1 || pregunta.tipoPreguntaId == 2) {
      return _textController.text.trim().isNotEmpty;
    } else if (pregunta.tipoPreguntaId == 3) {
      return _selectedSingleOption != null;
    } else if (pregunta.tipoPreguntaId == 4) {
      return _selectedMultiOptions.isNotEmpty;
    }
    return true;
  }

  Future<void> _submitStepAndAdvance() async {
    if (!_validateCurrentAnswer()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta pregunta es obligatoria.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final answerPayload = _collectCurrentAnswer();
    _respuestasAcumuladas.add(answerPayload);

    setState(() {
      _isSubmittingStep = true;
    });

    final isOnline = await OfflineSyncService.instance.isOnline();

    // Si el backend es remoto y estamos online:
    if (isOnline && !_session!.sesionId.startsWith('local_')) {
      try {
        final baseUrl = AudioService.baseUrl;
        final uri = Uri.parse(
            '$baseUrl/public/entregas/${widget.entregaId}/adaptativa/siguiente');

        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'accept': 'application/json'
          },
          body: jsonEncode({
            'sesion_id': _session!.sesionId,
            'entrega_id': widget.entregaId,
            'respuesta': answerPayload,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          final updatedSession = AdaptiveSession.fromJson(data,
              fallbackEntregaId: widget.entregaId);
          _advanceToNextQuestion(updatedSession);
          return;
        }
      } catch (_) {
        // Fallback a avance local
      }
    }

    // Modo local / Fallback por pasos
    _advanceLocalStep();
  }

  void _advanceLocalStep() {
    _currentStepIndex++;
    if (_currentStepIndex < _fallbackQuestions.length) {
      final nextQ = _fallbackQuestions[_currentStepIndex];
      final newSession = AdaptiveSession(
        sesionId: _session!.sesionId,
        entregaId: widget.entregaId,
        campanaId: widget.campaignId,
        preguntaActual: nextQ,
        pasoActual: _currentStepIndex + 1,
        progreso: (_currentStepIndex + 1) / _fallbackQuestions.length,
        completada: false,
      );
      _advanceToNextQuestion(newSession);
    } else {
      // Encuesta completada
      _finishAdaptiveSurvey();
    }
  }

  void _advanceToNextQuestion(AdaptiveSession newSession) {
    _transitionController.reverse().then((_) {
      _textController.clear();
      _selectedSingleOption = null;
      _selectedMultiOptions.clear();

      setState(() {
        _session = newSession;
        _isSubmittingStep = false;
      });

      if (newSession.completada) {
        _finishAdaptiveSurvey();
      } else {
        _transitionController.forward();
      }
    });
  }

  Future<void> _finishAdaptiveSurvey() async {
    setState(() {
      _isSubmittingStep = true;
    });

    final payload = {'respuestas_preguntas': _respuestasAcumuladas};
    final isOnline = await OfflineSyncService.instance.isOnline();

    if (isOnline) {
      try {
        final baseUrl = AudioService.baseUrl;
        final uri = Uri.parse(
            '$baseUrl/public/entregas/${widget.entregaId}/respuestas');
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'accept': 'application/json'
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          _showCompletionDialog(isOffline: false);
          return;
        }
      } catch (_) {}
    }

    // Guardado offline
    await OfflineSyncService.instance.enqueueAudioSurvey(
      entregaId: widget.entregaId,
      campaignId: widget.campaignId,
      campaignName: widget.campaignName,
      filePath: '',
      payload: payload,
    );

    _showCompletionDialog(isOffline: true);
  }

  void _showCompletionDialog({required bool isOffline}) {
    setState(() {
      _isSubmittingStep = false;
      _session = AdaptiveSession(
        sesionId: _session?.sesionId ?? '',
        entregaId: widget.entregaId,
        completada: true,
        progreso: 1.0,
      );
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isOffline ? Icons.cloud_off : Icons.check_circle,
                color: isOffline ? Colors.orange : Colors.green),
            const SizedBox(width: 10),
            const Text('¡Encuesta Finalizada!'),
          ],
        ),
        content: Text(
          isOffline
              ? 'Has respondido todas las preguntas adaptativas. Las respuestas quedaron guardadas en tu dispositivo y se sincronizarán al recuperar señal.'
              : 'Respuestas registradas exitosamente en el servidor.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Dialog
              Navigator.pop(context); // Screen
            },
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Encuesta Adaptativa')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Encuesta Adaptativa')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _initAdaptiveSession,
                  child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final pregunta = _session?.preguntaActual;
    final progreso = _session?.progreso ?? 0.0;
    final paso = _session?.pasoActual ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Encuesta Adaptativa'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de progreso interactiva
          LinearProgressIndicator(
            value: progreso > 0 ? progreso : null,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
            minHeight: 6,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pregunta #$paso',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1565C0)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Modo Adaptativo Dinámico',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0)),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: pregunta != null
                    ? _buildQuestionContent(pregunta)
                    : const SizedBox(),
              ),
            ),
          ),

          // Botón inferior para avanzar
          Container(
            padding: const EdgeInsets.all(20),
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
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmittingStep ? null : _submitStepAndAdvance,
                icon: _isSubmittingStep
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward),
                label: Text(
                  _isSubmittingStep ? 'Procesando paso...' : 'Continuar',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContent(Question pregunta) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pregunta.texto,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              pregunta.obligatorio
                  ? 'Respuesta obligatoria'
                  : 'Respuesta opcional',
              style: TextStyle(
                fontSize: 12,
                color: pregunta.obligatorio
                    ? Colors.orange[800]
                    : Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const Divider(height: 32),
            if (pregunta.tipoPreguntaId == 1) ...[
              TextFormField(
                controller: _textController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Escribe la respuesta del encuestado...',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else if (pregunta.tipoPreguntaId == 2) ...[
              TextFormField(
                controller: _textController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Ingresa un valor numérico...',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else if (pregunta.tipoPreguntaId == 3) ...[
              Column(
                children: pregunta.opciones.map((opcion) {
                  return RadioListTile<String>(
                    title: Text(opcion.texto ?? 'Opción'),
                    value: opcion.id,
                    groupValue: _selectedSingleOption,
                    activeColor: const Color(0xFF1565C0),
                    onChanged: (val) {
                      setState(() {
                        _selectedSingleOption = val;
                      });
                    },
                  );
                }).toList(),
              ),
            ] else if (pregunta.tipoPreguntaId == 4) ...[
              Column(
                children: pregunta.opciones.map((opcion) {
                  final isChecked = _selectedMultiOptions.contains(opcion.id);
                  return CheckboxListTile(
                    title: Text(opcion.texto ?? 'Opción'),
                    value: isChecked,
                    activeColor: const Color(0xFF1565C0),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedMultiOptions.add(opcion.id);
                        } else {
                          _selectedMultiOptions.remove(opcion.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
