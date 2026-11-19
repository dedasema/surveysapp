import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ocr_service.dart';
import '../services/offline_sync_service.dart';
import '../models/campaign_models.dart';
import 'survey_review_screen.dart';

class OCRScreen extends StatefulWidget {
  const OCRScreen({super.key});

  @override
  State<OCRScreen> createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> {
  File? _selectedImage;
  Map<String, dynamic>? _ocrResult;
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();
  final OCRService _ocrService = OCRService();

  Future<bool> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;

    status = await Permission.camera.request();
    if (status.isGranted) return true;

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permiso de Cámara Requerido'),
          content: const Text(
            'Para digitalizar formularios físicos mediante OCR, la aplicación necesita acceso a la cámara.\n\nPuedes habilitarlo en los ajustes de la aplicación.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Abrir Ajustes'),
            ),
          ],
        ),
      );
    }
    return false;
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final hasPermission = await _ensureCameraPermission();
      if (!hasPermission) return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90, // Aumentar calidad para mejor OCR
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _ocrResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    final isOnline = await OfflineSyncService.instance.isOnline();
    if (!isOnline) {
      // Manejo Offline: Encolar la imagen para procesamiento posterior
      _showOfflineEnqueueDialog();
      return;
    }

    setState(() {
      _isProcessing = true;
      _ocrResult = null;
    });

    final result = await _ocrService.processImage(_selectedImage!);

    setState(() {
      _isProcessing = false;
      _ocrResult = result;
    });

    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al procesar la imagen con OCR en el servidor.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Respuestas extraídas con IA con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showOfflineEnqueueDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.orange),
            SizedBox(width: 10),
            Text('Modo Offline'),
          ],
        ),
        content: const Text(
          'No tienes conexión a internet en este momento.\n\n'
          '¿Deseas guardar la foto del formulario en la cola local? Se procesará automáticamente en cuanto recuperes señal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final entregaId = 'offline_ocr_${DateTime.now().millisecondsSinceEpoch}';
              await OfflineSyncService.instance.enqueueOCRSurvey(
                entregaId: entregaId,
                filePath: _selectedImage!.path,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Formulario encolado para sincronización offline.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Guardar Offline'),
          ),
        ],
      ),
    );
  }

  void _showImageSourceDialog() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(isTablet ? 32.0 : 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Seleccionar Imagen',
                style: TextStyle(
                  fontSize: isTablet ? 22 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isTablet ? 24 : 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Cámara',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                    isTablet: isTablet,
                  ),
                  _buildSourceOption(
                    icon: Icons.photo_library,
                    label: 'Galería',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                    isTablet: isTablet,
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 24 : 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: isTablet ? 48 : 40,
              color: const Color(0xFF1565C0),
            ),
            SizedBox(height: isTablet ? 12 : 8),
            Text(
              label,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOCRResultCard(Map<String, dynamic> result, bool isTablet) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.analytics,
                  color: Color(0xFF1565C0),
                ),
                SizedBox(width: isTablet ? 12 : 8),
                Text(
                  'Resultado del Procesamiento OCR',
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 20 : 16),

            // Información de la entrega
            if (result['entrega_id'] != null) ...[
              _buildInfoSection(
                'ID de Entrega',
                result['entrega_id'].toString(),
                isTablet,
              ),
              SizedBox(height: isTablet ? 16 : 12),
            ],

            // Respuestas procesadas
            () {
              List<dynamic> respuestas = [];
              if (result['respuestas'] is List) {
                respuestas = result['respuestas'] as List;
              } else if (result['respuestas_preguntas'] is List) {
                respuestas = result['respuestas_preguntas'] as List;
              } else if (result['ocr_result'] != null &&
                  result['ocr_result']['respuestas_preguntas'] is List) {
                respuestas =
                    result['ocr_result']['respuestas_preguntas'] as List;
              }

              if (respuestas.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Respuestas Detectadas:',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                  SizedBox(height: isTablet ? 12 : 8),
                  ...List.generate(
                    respuestas.length,
                    (index) {
                      final respuesta = respuestas[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: isTablet ? 12.0 : 8.0),
                        padding: EdgeInsets.all(isTablet ? 16.0 : 12.0),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Respuesta ${index + 1}',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: isTablet ? 8 : 4),
                            if (respuesta['texto'] != null)
                              Text('Texto: ${respuesta['texto']}'),
                            if (respuesta['numero'] != null)
                              Text('Número: ${respuesta['numero']}'),
                            if (respuesta['opcion_id'] != null)
                              Text('Opción ID: ${respuesta['opcion_id']}'),
                            if (respuesta['tipo_pregunta_id'] != null)
                              Text('Tipo: ${respuesta['tipo_pregunta_id']}'),
                          ],
                        ),
                      );
                    },
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                ],
              );
            }(),

            // Plantilla usada
            if (result['plantilla_usada'] != null) ...[
              Text(
                'Plantilla Utilizada:',
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1565C0),
                ),
              ),
              SizedBox(height: isTablet ? 12 : 8),

              if (result['plantilla_usada']['preguntas'] != null)
                ...List.generate(
                  result['plantilla_usada']['preguntas'].length,
                      (index) {
                    final pregunta = result['plantilla_usada']['preguntas'][index];
                    return Container(
                      margin: EdgeInsets.only(bottom: isTablet ? 8.0 : 6.0),
                      padding: EdgeInsets.all(isTablet ? 12.0 : 10.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${pregunta['orden']}. ${pregunta['texto']}',
                            style: TextStyle(
                              fontSize: isTablet ? 15 : 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (pregunta['opciones'] != null &&
                              pregunta['opciones'].isNotEmpty) ...[
                            SizedBox(height: isTablet ? 6 : 4),
                            ...List.generate(
                              pregunta['opciones'].length,
                                  (optIndex) {
                                final opcion = pregunta['opciones'][optIndex];
                                return Padding(
                                  padding: EdgeInsets.only(left: isTablet ? 16.0 : 12.0),
                                  child: Text(
                                    '• ${opcion['texto']}',
                                    style: TextStyle(
                                      fontSize: isTablet ? 14 : 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],

            // Botón para revisar y validar en formulario interactivo
            if (result['plantilla_usada'] != null && result['entrega_id'] != null) ...[
              SizedBox(height: isTablet ? 20 : 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final plantilla = SurveyTemplate.fromJson(result['plantilla_usada']);
                    List<dynamic> respuestas = [];
                    if (result['respuestas'] is List) {
                      respuestas = result['respuestas'];
                    } else if (result['respuestas_preguntas'] is List) {
                      respuestas = result['respuestas_preguntas'];
                    } else if (result['ocr_result'] != null &&
                        result['ocr_result']['respuestas_preguntas'] is List) {
                      respuestas = result['ocr_result']['respuestas_preguntas'];
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SurveyReviewScreen(
                          entregaId: result['entrega_id'].toString(),
                          plantilla: plantilla,
                          initialRespuestas: respuestas,
                          canalId: 4,
                          localFilePath: _selectedImage?.path,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_note, size: 22),
                  label: const Text('Revisar y Validar en Formulario'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],

            // URL de la imagen procesada
            if (result['image_url'] != null) ...[
              SizedBox(height: isTablet ? 16 : 12),
              _buildInfoSection(
                'Imagen Procesada',
                result['image_url'].toString(),
                isTablet,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, String content, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1565C0),
          ),
        ),
        SizedBox(height: isTablet ? 6 : 4),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isTablet ? 12.0 : 10.0),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Procesamiento OCR',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 800 : double.infinity,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Información del servicio
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.document_scanner,
                        size: isTablet ? 64 : 48,
                        color: const Color(0xFF1565C0),
                      ),
                      SizedBox(height: isTablet ? 16 : 12),
                      Text(
                        'Procesamiento OCR Inteligente',
                        style: TextStyle(
                          fontSize: isTablet ? 24 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: isTablet ? 12 : 8),
                      Text(
                        'Selecciona una imagen de encuesta para extraer y procesar automáticamente las respuestas usando IA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isTablet ? 24 : 20),

              // Imagen seleccionada
              if (_selectedImage != null) ...[
                Card(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      height: isTablet ? 300 : 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(height: isTablet ? 20 : 16),
              ],

              // Botones de acción
              SizedBox(
                height: isTablet ? 56 : 48,
                child: ElevatedButton.icon(
                  onPressed: _showImageSourceDialog,
                  icon: const Icon(Icons.add_a_photo),
                  label: Text(
                    _selectedImage == null
                        ? 'Seleccionar Imagen'
                        : 'Cambiar Imagen',
                    style: TextStyle(fontSize: isTablet ? 16 : 14),
                  ),
                ),
              ),

              if (_selectedImage != null) ...[
                SizedBox(height: isTablet ? 16 : 12),
                SizedBox(
                  height: isTablet ? 56 : 48,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _processImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    icon: _isProcessing
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Icon(Icons.analytics),
                    label: Text(
                      _isProcessing ? 'Procesando...' : 'Procesar con OCR',
                      style: TextStyle(fontSize: isTablet ? 16 : 14),
                    ),
                  ),
                ),
              ],

              // Resultado OCR
              if (_ocrResult != null) ...[
                SizedBox(height: isTablet ? 24 : 20),
                _buildOCRResultCard(_ocrResult!, isTablet),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
