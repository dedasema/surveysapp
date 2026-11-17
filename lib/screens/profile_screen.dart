import 'package:flutter/material.dart';
import '../models/auth_models.dart';
import 'package:intl/intl.dart';
import '../services/app_config_service.dart';
import '../services/notification_service.dart';

class ProfileScreen extends StatelessWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1565C0),
              Color(0xFFF5F5F5),
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 55,
                backgroundColor: const Color(0xFF1565C0),
                child: Text(
                  user.nombre.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.nombre,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user.rol.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Información Personal',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          icon: Icons.email,
                          title: 'Correo Electrónico',
                          value: user.email,
                        ),
                        _buildInfoCard(
                          icon: Icons.phone,
                          title: 'Teléfono',
                          value: user.telefono,
                        ),
                        _buildInfoCard(
                          icon: Icons.business,
                          title: 'Tipo de Cuenta',
                          value: user.tipo.toUpperCase(),
                        ),
                        _buildInfoCard(
                          icon: Icons.calendar_today,
                          title: 'Fecha de Registro',
                          value: DateFormat('dd/MM/yyyy').format(user.creadoEn),
                        ),
                        _buildInfoCard(
                          icon: Icons.verified,
                          title: 'Estado',
                          value: user.estado.toUpperCase(),
                          valueColor: user.estado == 'activo'
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Ajustes de Presentación y Alertas',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedBuilder(
                          animation: AppConfigService.instance,
                          builder: (context, _) {
                            final config = AppConfigService.instance;
                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  children: [
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      secondary: Icon(
                                        Icons.bolt,
                                        color: config.isDemoMode
                                            ? Colors.orange
                                            : Colors.grey,
                                      ),
                                      title: const Text(
                                        'Modo Presentación / Demo (1s)',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        config.isDemoMode
                                            ? 'Sondeo ultrarrápido activo para la demo.'
                                            : 'Sondeo normal (30 seg) para ahorro.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: config.isDemoMode
                                              ? Colors.orange[800]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                      value: config.isDemoMode,
                                      activeColor: Colors.orange,
                                      onChanged: (val) async {
                                        await config.setDemoMode(val);
                                        if (val) {
                                          await NotificationService.instance
                                              .showTestNotification(
                                                  isDemo: true);
                                        }
                                      },
                                    ),
                                    const Divider(),
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      secondary: Icon(
                                        Icons.notifications_active,
                                        color: config.isNotificationsEnabled
                                            ? const Color(0xFF1565C0)
                                            : Colors.grey,
                                      ),
                                      title: const Text(
                                        'Notificaciones Locales Nativas',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: const Text(
                                        'Alertas en la barra de Android al transcribir o sincronizar.',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      value: config.isNotificationsEnabled,
                                      activeColor: const Color(0xFF1565C0),
                                      onChanged: (val) async {
                                        await config.setNotificationsEnabled(val);
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          await NotificationService.instance
                                              .showTestNotification(
                                                  isDemo: false);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Notificación enviada a la barra de Android'),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                            Icons.notifications_none),
                                        label: const Text(
                                            'Lanzar Notificación de Prueba'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF1565C0),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
