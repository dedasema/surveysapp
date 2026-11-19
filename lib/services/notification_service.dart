import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app_config_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  NotificationService._init();

  /// Inicializa el servicio de notificaciones locales.
  Future<void> init() async {
    if (_isInitialized) return;

    // Configuración para Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuración para iOS / macOS
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (kDebugMode) {
          debugPrint('Notificación tocada con payload: ${response.payload}');
        }
      },
    );

    await requestPermission();
    _isInitialized = true;
  }

  /// Solicita permisos explícitos para notificaciones (Android 13+ e iOS)
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted =
          await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final iosImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Muestra una notificación local nativa con vibración y sonido
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'surveys_events_channel',
    String channelName = 'Eventos y Tareas de Encuestas',
    String channelDescription =
        'Notificaciones sobre estado de transcripciones, sincronizaciones y campañas',
  }) async {
    // Si el usuario desactivó las notificaciones en los ajustes de la app, no emitir alerta
    if (!AppConfigService.instance.isNotificationsEnabled) {
      if (kDebugMode) {
        debugPrint(
            'Notificación suprimida (notificaciones desactivadas por el usuario)');
      }
      return;
    }

    if (!_isInitialized) {
      await init();
    }

    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'SurveysApp',
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    final DarwinNotificationDetails darwinNotificationDetails =
        const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Notificación específica para estado de transcripción de audio
  Future<void> notifyAudioTranscription({
    required String entregaId,
    required bool isSuccess,
    String? details,
  }) async {
    final int notifId = entregaId.hashCode.abs() % 100000;
    if (isSuccess) {
      await showNotification(
        id: notifId,
        title: '🎙️ Transcripción completada',
        body: details ??
            'El audio de la entrega $entregaId fue procesado con éxito.',
        payload: 'audio_success:$entregaId',
      );
    } else {
      await showNotification(
        id: notifId,
        title: '⚠️ Error en transcripción',
        body: details ??
            'Hubo un inconveniente al procesar el audio de la entrega $entregaId.',
        payload: 'audio_error:$entregaId',
      );
    }
  }

  /// Notificación específica para estado de sincronización de cola offline
  Future<void> notifyOfflineSync({
    required int syncedCount,
    int failedCount = 0,
  }) async {
    final int notifId = 88888;
    if (syncedCount > 0 && failedCount == 0) {
      await showNotification(
        id: notifId,
        title: '🔄 Sincronización exitosa',
        body: 'Se subieron $syncedCount encuestas pendientes al servidor.',
        payload: 'sync_success',
      );
    } else if (failedCount > 0) {
      await showNotification(
        id: notifId,
        title: '⚠️ Sincronización con advertencias',
        body:
            '$syncedCount sincronizadas, pero $failedCount fallaron. Revisá la cola.',
        payload: 'sync_warning',
      );
    }
  }

  /// Notificación de prueba
  Future<void> showTestNotification({bool isDemo = false}) async {
    await showNotification(
      id: 99999,
      title: isDemo ? '🚀 Modo Demo Activo' : '🔔 Notificación de Prueba',
      body: isDemo
          ? 'Sondeo rápido de 1s habilitado para la presentación.'
          : 'El sistema de notificaciones locales nativas está funcionando correctamente.',
      payload: 'test_notification',
    );
  }
}
