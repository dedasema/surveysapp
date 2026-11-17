import 'package:flutter/material.dart';
import '../models/auth_models.dart';
import 'package:intl/intl.dart';
import '../services/app_config_service.dart';
import '../services/notification_service.dart';

class ProfileScreen extends StatelessWidget {
  final User? user;

  const ProfileScreen({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    final effectiveUser = user ??
        User(
          id: 'operador-campo',
          email: 'operador@encuestas.com',
          rol: 'operador',
          creadoEn: DateTime.now(),
          tipo: 'operador',
          nombre: 'Operador de Campo',
          telefono: '',
          estado: 'activo',
        );

    final initial = effectiveUser.nombre.trim().isNotEmpty
        ? effectiveUser.nombre.trim()[0].toUpperCase()
        : 'O';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Mi Perfil',
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // Avatar & Header Minimalista
            Center(
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFC7D2FE), width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4338CA),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    effectiveUser.nombre,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      effectiveUser.rol.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D4ED8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Información Personal
            _buildSectionHeader('INFORMACIÓN DE CUENTA'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildProfileRow(
                    icon: Icons.alternate_email,
                    label: 'Correo Electrónico',
                    value: effectiveUser.email,
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                  _buildProfileRow(
                    icon: Icons.phone_outlined,
                    label: 'Teléfono',
                    value: effectiveUser.telefono.isNotEmpty
                        ? effectiveUser.telefono
                        : 'No registrado',
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                  _buildProfileRow(
                    icon: Icons.badge_outlined,
                    label: 'Tipo de Cuenta',
                    value: effectiveUser.tipo.toUpperCase(),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                  _buildProfileRow(
                    icon: Icons.event_outlined,
                    label: 'Fecha de Registro',
                    value: DateFormat('dd/MM/yyyy').format(effectiveUser.creadoEn),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                  _buildProfileRow(
                    icon: Icons.check_circle_outline,
                    label: 'Estado de Cuenta',
                    value: effectiveUser.estado.toUpperCase(),
                    valueColor: effectiveUser.estado == 'activo'
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Ajustes de Presentación y Alertas
            _buildSectionHeader('MODO DEMO & NOTIFICACIONES'),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: AppConfigService.instance,
              builder: (context, _) {
                final config = AppConfigService.instance;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: config.isDemoMode
                                ? const Color(0xFFFFFBEB)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.bolt,
                            color: config.isDemoMode
                                ? const Color(0xFFD97706)
                                : const Color(0xFF64748B),
                            size: 20,
                          ),
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
                              ? 'Sondeo instantáneo de 1 seg habilitado.'
                              : 'Sondeo normal de 30 seg para ahorro de red.',
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
                          if (val) {
                            await NotificationService.instance
                                .showTestNotification(isDemo: true);
                          }
                        },
                      ),
                      const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: config.isNotificationsEnabled
                                ? const Color(0xFFEFF6FF)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.notifications_active_outlined,
                            color: config.isNotificationsEnabled
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF64748B),
                            size: 20,
                          ),
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
                          'Alertas nativas al procesar audio o sincronizar.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        value: config.isNotificationsEnabled,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (val) async {
                          await config.setNotificationsEnabled(val);
                        },
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () async {
                              await NotificationService.instance
                                  .showTestNotification(isDemo: false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Notificación enviada a la barra de Android'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.notifications_none, size: 18),
                            label: const Text(
                              'Lanzar Notificación de Prueba',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildProfileRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF64748B)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
