import 'dart:async';
import 'package:flutter/material.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import '../services/version_check_service.dart';
import 'profile_screen.dart';
import 'ocr_screen.dart';
import 'audio_campaigns_screen.dart';
import 'operator_stats_screen.dart';
import 'sync_queue_screen.dart';
import 'login_screen.dart';
import '../services/offline_sync_service.dart';
import '../services/app_config_service.dart';
import '../services/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  User? _currentUser;
  bool _isLoading = true;
  StreamSubscription<bool>? _sessionSub;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final update = await VersionCheckService.instance.checkForUpdate();
      if (update != null && mounted) {
        VersionCheckService.instance.showUpdateDialog(context, update);
      }
    });
    _sessionSub = AuthService.instance.sessionExpiredStream.listen((expired) {
      if (expired && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Tu sesión ha expirado. Por favor ingresa nuevamente.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final authService = AuthService();
    final user = await authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final authService = AuthService();
    await authService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _showDemoSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final config = AppConfigService.instance;
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune,
                            color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Ajustes de Demostración',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          secondary: Icon(
                            Icons.bolt,
                            color: config.isDemoMode
                                ? const Color(0xFFD97706)
                                : const Color(0xFF94A3B8),
                          ),
                          title: const Text(
                            'Modo Presentación / Demo (1s)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Text(
                            config.isDemoMode
                                ? 'Sondeo ultrarrápido activo para respuesta instantánea.'
                                : 'Sondeo normal (30s) para ahorro de batería.',
                            style: TextStyle(
                              fontSize: 12,
                              color: config.isDemoMode
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          value: config.isDemoMode,
                          activeColor: const Color(0xFFD97706),
                          onChanged: (val) async {
                            await config.setDemoMode(val);
                            setModalState(() {});
                            setState(() {});
                            if (val) {
                              await NotificationService.instance
                                  .showTestNotification(isDemo: true);
                            }
                          },
                        ),
                        const Divider(
                            height: 1, indent: 48, color: Color(0xFFE2E8F0)),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          secondary: Icon(
                            Icons.notifications_active_outlined,
                            color: config.isNotificationsEnabled
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF94A3B8),
                          ),
                          title: const Text(
                            'Notificaciones Locales',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: const Text(
                            'Alertas en la barra de Android al transcribir o sincronizar.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          value: config.isNotificationsEnabled,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (val) async {
                            await config.setNotificationsEnabled(val);
                            setModalState(() {});
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.dns_outlined,
                                size: 18, color: Color(0xFF2563EB)),
                            SizedBox(width: 8),
                            Text(
                              'Servidor Backend (URL Base)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Activa: ${config.baseUrl}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  final controller = TextEditingController(
                                      text: config.baseUrl);
                                  showDialog(
                                    context: context,
                                    builder: (dlgContext) => AlertDialog(
                                      title:
                                          const Text('Cambiar URL del Backend'),
                                      content: TextField(
                                        controller: controller,
                                        decoration: const InputDecoration(
                                          hintText: 'http://ip_o_dominio:8000',
                                          labelText: 'URL Base',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dlgContext),
                                          child: const Text('Cancelar'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            final val = controller.text.trim();
                                            if (val.isNotEmpty) {
                                              await config.setBaseUrl(val);
                                              if (dlgContext.mounted) {
                                                Navigator.pop(dlgContext);
                                              }
                                              setModalState(() {});
                                              setState(() {});
                                            }
                                          },
                                          child: const Text('Guardar'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text('Editar URL',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                await config
                                    .setBaseUrl(ApiConfig.defaultBaseUrl);
                                setModalState(() {});
                                setState(() {});
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'URL restablecida por defecto')),
                                  );
                                }
                              },
                              child: const Text('Restablecer',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.notifications_none, size: 18),
                      label: const Text(
                        'Lanzar Notificación de Prueba',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () async {
                        await NotificationService.instance
                            .showTestNotification(isDemo: false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Notificación enviada a la barra de Android'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final initial = (_currentUser?.nombre.trim().isNotEmpty == true)
        ? _currentUser!.nombre.trim()[0].toUpperCase()
        : 'O';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.how_to_vote_outlined,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text(
              'SurveysApp',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        actions: [
          StreamBuilder<Map<String, int>>(
            stream: OfflineSyncService.instance.countsStream,
            builder: (context, snapshot) {
              final counts = snapshot.data ?? {};
              final pending =
                  (counts['pending'] ?? 0) + (counts['failed'] ?? 0);
              return IconButton(
                icon: Badge(
                  isLabelVisible: pending > 0,
                  label: Text('$pending'),
                  backgroundColor: const Color(0xFFD97706),
                  child: Icon(
                    pending > 0 ? Icons.sync_problem : Icons.sync,
                    color: const Color(0xFF475569),
                    size: 22,
                  ),
                ),
                tooltip: 'Cola de sincronización ($pending pendientes)',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SyncQueueScreen()),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.tune,
              color: AppConfigService.instance.isDemoMode
                  ? const Color(0xFFD97706)
                  : const Color(0xFF475569),
              size: 22,
            ),
            tooltip: 'Ajustes y Modo Demo',
            onPressed: () => _showDemoSettingsSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline,
                color: Color(0xFF475569), size: 22),
            tooltip: 'Mi Perfil',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(user: _currentUser),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF64748B), size: 20),
            tooltip: 'Cerrar Sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta de Usuario Minimalista
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentUser?.nombre ?? 'Operador de Campo',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _currentUser?.email ?? 'Sesión activa en terreno',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  (_currentUser?.rol ?? 'operador')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF475569),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'En línea',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Indicador de Respuestas Pendientes y Alerta de Sincronización (A4)
              StreamBuilder<Map<String, int>>(
                stream: OfflineSyncService.instance.countsStream,
                builder: (context, snapshot) {
                  final counts = snapshot.data ?? {};
                  final pending =
                      (counts['pending'] ?? 0) + (counts['failed'] ?? 0);
                  return FutureBuilder<bool>(
                    future:
                        OfflineSyncService.instance.hasPendingOlderThan7Days(),
                    builder: (context, olderSnap) {
                      final hasOlder = olderSnap.data == true;
                      return _buildSyncCard(context, pending, hasOlder);
                    },
                  );
                },
              ),

              // Banner Modo Demo
              AnimatedBuilder(
                animation: AppConfigService.instance,
                builder: (context, _) {
                  if (!AppConfigService.instance.isDemoMode) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt,
                            color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Modo Demo Activo (Sondeo rápido 1s)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showDemoSettingsSheet(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Configurar',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Sección Servicios
              const Row(
                children: [
                  Text(
                    'Servicios de Campo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Grid de Servicios con Proporciones Perfectas
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.15,
                children: [
                  _buildServiceCard(
                    title: 'Encuestas OCR',
                    subtitle: 'Escanear formularios físicos con IA',
                    icon: Icons.document_scanner_outlined,
                    iconColor: const Color(0xFF2563EB),
                    iconBgColor: const Color(0xFFEFF6FF),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const OCRScreen()),
                      );
                    },
                  ),
                  _buildServiceCard(
                    title: 'Encuestas por Audio',
                    subtitle: 'Respuestas de voz y transcripción',
                    icon: Icons.mic_none_outlined,
                    iconColor: const Color(0xFF059669),
                    iconBgColor: const Color(0xFFECFDF5),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AudioCampaignsScreen()),
                      );
                    },
                  ),
                  _buildServiceCard(
                    title: 'Estadísticas',
                    subtitle: 'Métricas de campo y cola outbox',
                    icon: Icons.bar_chart_outlined,
                    iconColor: const Color(0xFFD97706),
                    iconBgColor: const Color(0xFFFFFBEB),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OperatorStatsScreen(user: _currentUser),
                        ),
                      );
                    },
                  ),
                  _buildServiceCard(
                    title: 'Mi Perfil',
                    subtitle: 'Credenciales y ajustes de demo',
                    icon: Icons.person_outline,
                    iconColor: const Color(0xFF475569),
                    iconBgColor: const Color(0xFFF1F5F9),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProfileScreen(user: _currentUser),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncCard(BuildContext context, int pending, bool hasOlder) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasOlder
            ? const Color(0xFFFEF2F2)
            : (pending > 0 ? const Color(0xFFEFF6FF) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasOlder
              ? const Color(0xFFFCA5A5)
              : (pending > 0
                  ? const Color(0xFFBFDBFE)
                  : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasOlder) ...[
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¡Atención! Hay respuestas pendientes de más de 7 días sin sincronizar.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Icon(
                pending > 0
                    ? Icons.cloud_upload_outlined
                    : Icons.cloud_done_outlined,
                color: hasOlder
                    ? const Color(0xFFDC2626)
                    : (pending > 0
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF16A34A)),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pending > 0
                      ? '$pending respuestas pendientes de sincronizar'
                      : 'Todas las respuestas están sincronizadas',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasOlder
                        ? const Color(0xFF991B1B)
                        : (pending > 0
                            ? const Color(0xFF1E40AF)
                            : const Color(0xFF15803D)),
                  ),
                ),
              ),
              if (pending > 0)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sincronizar ahora',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Iniciando sincronización por lotes...')),
                    );
                    await OfflineSyncService.instance.syncPendingQueue();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
