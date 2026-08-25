import 'package:flutter/material.dart';
import '../models/auth_models.dart';
import '../services/database_helper.dart';
import '../services/offline_sync_service.dart';
import 'sync_queue_screen.dart';
import 'package:intl/intl.dart';

class OperatorStatsScreen extends StatefulWidget {
  final User user;

  const OperatorStatsScreen({super.key, required this.user});

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
    final counts = await DatabaseHelper.instance.getQueueCounts();
    if (mounted) {
      setState(() {
        _queueCounts = counts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('EEEE, d MMMM', 'es').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Métricas del Operador'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tarjeta de resumen de operador
                    _buildOperatorHeader(todayStr),
                    const SizedBox(height: 20),

                    // KPIs del Operador
                    const Text(
                      'Actividad y Rendimiento',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildKPIGrid(),
                    const SizedBox(height: 20),

                    // Banner de Estado Offline
                    _buildSyncStatusCard(),
                    const SizedBox(height: 20),

                    // Consejos para trabajo de campo
                    _buildFieldTipsCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOperatorHeader(String todayStr) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                widget.user.nombre.isNotEmpty ? widget.user.nombre[0].toUpperCase() : 'O',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.nombre,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Operador de Campo • $todayStr',
                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      childAspectRatio: 1.3,
      children: [
        _buildKPICard(
          title: 'Sincronizadas Hoy',
          value: '$todaySynced',
          subtitle: 'Completadas en el día',
          icon: Icons.today,
          color: Colors.green,
        ),
        _buildKPICard(
          title: 'Pendientes Offline',
          value: '$pending',
          subtitle: 'En cola local',
          icon: Icons.cloud_queue,
          color: Colors.orange,
        ),
        _buildKPICard(
          title: 'Total Acumulado',
          value: '$totalSynced',
          subtitle: 'Histórico local',
          icon: Icons.task_alt,
          color: const Color(0xFF1565C0),
        ),
        _buildKPICard(
          title: 'Requieren Atención',
          value: '$failed',
          subtitle: 'Errores de subida',
          icon: Icons.error_outline,
          color: failed > 0 ? Colors.red : Colors.grey,
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(
              value,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    final pending = _queueCounts['pending'] ?? 0;
    final failed = _queueCounts['failed'] ?? 0;
    final hasPending = pending > 0 || failed > 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (hasPending ? Colors.orange : Colors.green).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            hasPending ? Icons.sync : Icons.cloud_done,
            color: hasPending ? Colors.orange : Colors.green,
            size: 28,
          ),
        ),
        title: Text(
          hasPending ? 'Cola de Sincronización ($pending pendientes)' : 'Sincronización al Día',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          hasPending
              ? 'Toca para revisar y gestionar los envíos pendientes.'
              : 'Todas las encuestas locales han sido enviadas al servidor.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SyncQueueScreen()),
          );
          _loadStats();
        },
      ),
    );
  }

  Widget _buildFieldTipsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFF9FBE7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Color(0xFF827717), size: 20),
                SizedBox(width: 8),
                Text(
                  'Buenas Prácticas en Campo',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF827717)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '• Si no tienes cobertura, sigue encuestando con normalidad. La app guardará todas las grabaciones y fotos localmente.\n'
              '• Al regresar a una zona con WiFi o 4G, la sincronización se activará automáticamente sin perder datos.',
              style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
