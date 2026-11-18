class ApiConfig {
  /// URL base por defecto del backend en AWS
  static const String defaultBaseUrl = 'http://32.197.191.95:8000';

  static String _baseUrl = defaultBaseUrl;

  /// Retorna la URL base activa garantizando que no termine en '/'
  static String get baseUrl => _baseUrl;

  /// Permite actualizar dinámicamente la URL base
  static void setBaseUrl(String url) {
    var cleaned = url.trim();
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    _baseUrl = cleaned;
  }
}
