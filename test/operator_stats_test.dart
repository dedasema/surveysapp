import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surveys_app/screens/operator_stats_screen.dart';
import 'package:surveys_app/models/auth_models.dart';

void main() {
  testWidgets('OperatorStatsScreen renders without locale exception',
      (tester) async {
    final testUser = User(
      id: 'test-id',
      email: 'test@example.com',
      rol: 'operador',
      creadoEn: DateTime(2026, 1, 1),
      tipo: 'operador',
      nombre: 'Juan Perez',
      telefono: '12345678',
      estado: 'activo',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperatorStatsScreen(user: testUser),
      ),
    );

    // Initial pump renders title
    expect(find.text('Métricas del Operador'), findsOneWidget);

    // Pump to process async setState
    await tester.pump();

    expect(find.text('Juan Perez'), findsOneWidget);
    expect(find.text('Actividad y Rendimiento'), findsOneWidget);
    expect(find.text('Sincronizadas Hoy'), findsOneWidget);
    expect(find.text('Pendientes Offline'), findsOneWidget);
  });
}
