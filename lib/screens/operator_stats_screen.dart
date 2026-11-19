import 'package:flutter/material.dart';
import '../models/auth_models.dart';
import '../services/database_helper.dart';
import 'sync_queue_screen.dart';

class OperatorStatsScreen extends StatefulWidget {
  final User? user;

  const OperatorStatsScreen({super.key, this.user});

  @override
  State<OperatorStatsScreen> createState() => _OperatorStatsScreenState();
}

class _OperatorStatsScreenState extends State<OperatorStatsScreen> {
  Map<String, int> _queueCounts = {
    'pending': 0,
    'failed': 0,
    'synced': 0,
    'today_synced': 0,
    'total': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final counts = await DatabaseHelper.instance.getQueueCounts();
      if (mounted) {
        setState(() {
          _queueCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Aviso cargando métricas locales: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatTodayDate(DateTime date) {
    const days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    final dayName = days[(date.weekday - 1).clamp(0, 6)];
    final monthName = months[(date.month - 1).clamp(0, 11)];
    return '$dayName, ${date.day} de $monthName';
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = _formatTodayDate(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Métricas del Operador',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar métricas',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadStats();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tarjeta moderna del Operador
                    _buildOperatorHeader(todayStr),
                    const SizedBox(height: 24),

                    // Título de Sección
                    const Row(
                      children: [
                        Text(
                          'Actividad y Rendimiento',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Cuadrícula de KPIs
                    _buildKPIGrid(),
                    const SizedBox(height: 20),

                    // Banner de Estado de Sincronización
                    _buildSyncStatusCard(),
                    const SizedBox(height: 20),

                    // Buenas prácticas de campo
                    _buildFieldTipsCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOperatorHeader(String todayStr) {
    final userName = (widget.user?.nombre.trim().isNotEmpty == true)
        ? widget.user!.nombre.trim()
        : 'Operador de Campo';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'O';
    final role = (widget.user?.rol.isNotEmpty == true)
        ? widget.user!.rol.toUpperCase()
        : 'OPERADOR';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.08),
            offset: const Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                userInitial,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        todayStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIGrid() {
    final todaySynced = _queueCounts['today_synced'] ?? 0;
    final totalSynced = _queueCounts['synced'] ?? 0;
    final pending = _queueCounts['pending'] ?? 0;
    final failed = _queueCounts['failed'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        _buildKPICard(
          title: 'Sincronizadas Hoy',
          value: '$todaySynced',
          subtitle: 'Completadas en el día',
          icon: Icons.check_circle_outline,
          accentColor: const Color(0xFF16A34A),
          bgColor: const Color(0xFFF0FDF4),
        ),
        _buildKPICard(
          title: 'Pendientes Offline',
          value: '$pending',
          subtitle: 'En cola local',
          icon: Icons.cloud_upload_outlined,
          accentColor: const Color(0xFFD97706),
          bgColor: const Color(0xFFFFFBEB),
        ),
        _buildKPICard(
          title: 'Total Acumulado',
          value: '$totalSynced',
          subtitle: 'Histórico local',
          icon: Icons.inventory_2_outlined,
          accentColor: const Color(0xFF2563EB),
          bgColor: const Color(0xFFEFF6FF),
        ),
        _buildKPICard(
          title: 'Requieren Atención',
          value: '$failed',
          subtitle: 'Errores de subida',
          icon: Icons.error_outline,
          accentColor:
              failed > 0 ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
          bgColor:
              failed > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: accentColor,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    final pending = _queueCounts['pending'] ?? 0;
    final failed = _queueCounts['failed'] ?? 0;
    final hasPending = pending > 0 || failed > 0;

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SyncQueueScreen()),
        );
        _loadStats();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                hasPending ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.03),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasPending
                    ? const Color(0xFFFFFBEB)
                    : const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasPending ? Icons.sync : Icons.cloud_done_outlined,
                color: hasPending
                    ? const Color(0xFFD97706)
                    : const Color(0xFF16A34A),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPending
                        ? 'Cola de Sincronización ($pending pendientes)'
                        : 'Sincronización al Día',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasPending
                        ? 'Toca para revisar y gestionar los envíos pendientes.'
                        : 'Todas las encuestas locales han sido enviadas al servidor.',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldTipsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Color(0xFF475569), size: 18),
              SizedBox(width: 8),
              Text(
                'Buenas Prácticas en Campo',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Si no tienes cobertura, sigue encuestando con normalidad. La app guardará todas las grabaciones y fotos localmente en SQLite.\n'
            '• Al regresar a una zona con WiFi o 4G, la sincronización en segundo plano enviará todo automáticamente sin pérdida de datos.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
