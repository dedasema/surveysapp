import 'package:flutter/material.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authService = AuthService();
    final user = await authService.getCurrentUser();
    setState(() {
      _currentUser = user;
      _isLoading = false;
    });
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final config = AppConfigService.instance;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: Color(0xFF1565C0)),
                      const SizedBox(width: 10),
                      const Text(
                        'Ajustes de Presentación y Alertas',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.bolt,
                      color: config.isDemoMode ? Colors.orange : Colors.grey,
                    ),
                    title: const Text('Modo Presentación / Demo (1s)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      config.isDemoMode
                          ? 'Sondeo ultrarrápido activo (1 seg) para respuesta instantánea.'
                          : 'Sondeo normal (30 seg) para ahorro de batería.',
                      style: TextStyle(
                        fontSize: 12,
                        color: config.isDemoMode ? Colors.orange[800] : Colors.grey[600],
                      ),
                    ),
                    value: config.isDemoMode,
                    activeColor: Colors.orange,
                    onChanged: (val) async {
                      await config.setDemoMode(val);
                      setModalState(() {});
                      setState(() {});
                      if (val) {
                        await NotificationService.instance.showTestNotification(isDemo: true);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.notifications_active,
                      color: config.isNotificationsEnabled
                          ? const Color(0xFF1565C0)
                          : Colors.grey,
                    ),
                    title: const Text('Notificaciones Locales Nativas',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                      'Alertas en la barra de Android al completar transcripción o sincronización.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: config.isNotificationsEnabled,
                    activeColor: const Color(0xFF1565C0),
                    onChanged: (val) async {
                      await config.setNotificationsEnabled(val);
                      setModalState(() {});
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.notifications_none),
                      label: const Text('Probar Notificación Nativa'),
                      onPressed: () async {
                        await NotificationService.instance.showTestNotification(isDemo: false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Notificación de prueba enviada a la barra de Android'),
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          StreamBuilder<Map<String, int>>(
            stream: OfflineSyncService.instance.countsStream,
            builder: (context, snapshot) {
              final counts = snapshot.data ?? {};
              final pending = (counts['pending'] ?? 0) + (counts['failed'] ?? 0);
              return IconButton(
                icon: Badge(
                  isLabelVisible: pending > 0,
                  label: Text('$pending'),
                  backgroundColor: Colors.orange,
                  child: Icon(pending > 0 ? Icons.sync_problem : Icons.sync),
                ),
                tooltip: 'Cola de sincronización ($pending pendientes)',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SyncQueueScreen()),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.tune,
              color: AppConfigService.instance.isDemoMode
                  ? Colors.amberAccent
                  : Colors.white,
            ),
            tooltip: 'Ajustes y Modo Demo',
            onPressed: () => _showDemoSettingsSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(user: _currentUser!),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F5F5),
              Color(0xFFE3F2FD),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF1565C0),
                        child: Text(
                          _currentUser?.nombre.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bienvenido, ${_currentUser?.nombre ?? 'Usuario'}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentUser?.email ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _currentUser?.estado == 'activo'
                                    ? Colors.green[100]
                                    : Colors.red[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _currentUser?.estado.toUpperCase() ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _currentUser?.estado == 'activo'
                                      ? Colors.green[800]
                                      : Colors.red[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: AppConfigService.instance,
                builder: (context, _) {
                  if (!AppConfigService.instance.isDemoMode) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      border: Border.all(color: Colors.amber[800]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bolt, color: Colors.amber[900], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Modo Demo Activo (Sondeo rápido 1s)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.amber[900],
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showDemoSettingsSheet(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                          ),
                          child: const Text('Ajustes',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Servicios Disponibles',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildServiceCard(
                      title: 'Encuestas OCR',
                      subtitle: 'Procesar encuestas con IA',
                      icon: Icons.camera_alt,
                      color: const Color(0xFF1565C0),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OCRScreen(),
                          ),
                        );
                      },
                    ),
                    _buildServiceCard(
                      title: 'Encuestas por Audio',
                      subtitle: 'Grabar respuestas de voz',
                      icon: Icons.mic,
                      color: const Color(0xFFE91E63),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AudioCampaignsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildServiceCard(
                      title: 'Mi Perfil',
                      subtitle: 'Ver información personal',
                      icon: Icons.person,
                      color: const Color(0xFF388E3C),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(user: _currentUser!),
                          ),
                        );
                      },
                    ),
                    _buildServiceCard(
                      title: 'Estadísticas',
                      subtitle: 'Métricas de campo y cola offline',
                      icon: Icons.analytics,
                      color: const Color(0xFFFF7043),
                      onTap: () {
                        if (_currentUser != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OperatorStatsScreen(user: _currentUser!),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
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
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
