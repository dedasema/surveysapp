/// Configuración centralizada de endpoints y URLs base del sistema SurveySaaS.
class ApiConfig {
  /// URL base por defecto del backend en AWS, configurable por --dart-define=BACKEND_URL=...
  static const String defaultBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://32.197.191.95:8000',
  );

  /// URL de comprobación de actualizaciones de versión
  static const String defaultVersionJsonUrl = String.fromEnvironment(
    'VERSION_JSON_URL',
    defaultValue: 'http://32.197.191.95:8000/downloads/version.json',
  );

  static String _baseUrl = defaultBaseUrl;
  static String _versionJsonUrl = defaultVersionJsonUrl;

  /// Retorna la URL base activa garantizando que no termine en '/'
  static String get baseUrl => _baseUrl;

  /// Retorna la URL para consultar version.json
  static String get versionJsonUrl => _versionJsonUrl;

  /// Permite actualizar dinámicamente la URL base en tiempo de ejecución
  static void setBaseUrl(String url) {
    var cleaned = url.trim();
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (cleaned.isNotEmpty) {
      _baseUrl = cleaned;
    }
  }

  /// Permite actualizar la URL de comprobación de versiones
  static void setVersionJsonUrl(String url) {
    var cleaned = url.trim();
    if (cleaned.isNotEmpty) {
      _versionJsonUrl = cleaned;
    }
  }
}
