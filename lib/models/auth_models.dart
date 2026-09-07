class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

class LoginResponse {
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final int? expiresIn;
  final List<String> permissions;

  LoginResponse({
    required this.accessToken,
    this.refreshToken,
    required this.tokenType,
    this.expiresIn,
    this.permissions = const [],
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    List<String> perms = [];
    if (json['permissions'] is List) {
      perms = (json['permissions'] as List).map((p) => p.toString()).toList();
    } else if (json['permisos'] is List) {
      perms = (json['permisos'] as List).map((p) => p.toString()).toList();
    }

    return LoginResponse(
      accessToken: json['access_token'] ?? json['accessToken'] ?? '',
      refreshToken: json['refresh_token'] ?? json['refreshToken'],
      tokenType: json['token_type'] ?? 'bearer',
      expiresIn: json['expires_in'] is int ? json['expires_in'] : null,
      permissions: perms,
    );
  }
}

class TokenRefreshResponse {
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final int? expiresIn;

  TokenRefreshResponse({
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'bearer',
    this.expiresIn,
  });

  factory TokenRefreshResponse.fromJson(Map<String, dynamic> json) {
    return TokenRefreshResponse(
      accessToken: json['access_token'] ?? json['accessToken'] ?? '',
      refreshToken: json['refresh_token'] ?? json['refreshToken'],
      tokenType: json['token_type'] ?? 'bearer',
      expiresIn: json['expires_in'] is int ? json['expires_in'] : null,
    );
  }
}

class User {
  final String id;
  final String email;
  final String rol;
  final DateTime creadoEn;
  final String tipo;
  final String nombre;
  final String telefono;
  final String estado;

  User({
    required this.id,
    required this.email,
    required this.rol,
    required this.creadoEn,
    required this.tipo,
    required this.nombre,
    required this.telefono,
    required this.estado,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      rol: json['rol'],
      creadoEn: DateTime.parse(json['creado_en']),
      tipo: json['tipo'],
      nombre: json['nombre'],
      telefono: json['telefono'],
      estado: json['estado'],
    );
  }
}
