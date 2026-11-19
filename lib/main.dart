import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/app_config_service.dart';

/// DSN de Sentry para captura de errores no controlados, configurable por --dart-define=SENTRY_DSN=...
const String kSentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: '',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('es', null);
  } catch (_) {}
  await AppConfigService.instance.init();
  await NotificationService.instance.init();

  if (kSentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = kSentryDsn;
        options.tracesSampleRate = 1.0;
      },
      appRunner: () => runApp(const SurveysApp()),
    );
  } else {
    runApp(const SurveysApp());
  }
}

/// Widget raíz de la aplicación SurveysApp
class SurveysApp extends StatelessWidget {
  const SurveysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SurveysApp - Encuestas de Campo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF1565C0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
          ),
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Envoltorio de autenticación para enrutamiento inicial
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final authService = AuthService();
    final token = await authService.getAccessToken();

    if (token != null && token.isNotEmpty) {
      final user = await authService.getCurrentUser();
      if (mounted) {
        setState(() {
          _isLoggedIn = user != null;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isLoggedIn) {
      return const DashboardScreen();
    }

    return const LoginScreen();
  }
}
