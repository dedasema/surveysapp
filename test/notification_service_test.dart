import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surveys_app/services/app_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppConfigService (Demo Mode & Notifications Config)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial values default to normal mode and notifications enabled',
        () async {
      final config = AppConfigService.instance;
      await config.init();

      expect(config.isDemoMode, isFalse);
      expect(config.isNotificationsEnabled, isTrue);
      expect(config.pollingInterval, const Duration(seconds: 30));
    });

    test('enabling demo mode changes polling interval to 1s', () async {
      final config = AppConfigService.instance;
      await config.init();

      await config.setDemoMode(true);
      expect(config.isDemoMode, isTrue);
      expect(config.pollingInterval, const Duration(seconds: 1));

      await config.setDemoMode(false);
      expect(config.isDemoMode, isFalse);
      expect(config.pollingInterval, const Duration(seconds: 30));
    });

    test('toggling notifications updates configuration flag and storage',
        () async {
      final config = AppConfigService.instance;
      await config.init();

      await config.setNotificationsEnabled(false);
      expect(config.isNotificationsEnabled, isFalse);

      await config.setNotificationsEnabled(true);
      expect(config.isNotificationsEnabled, isTrue);
    });
  });
}
