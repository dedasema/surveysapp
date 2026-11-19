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
    String nombre = 'Operador';
    if (json['nombre_completo'] != null &&
        json['nombre_completo'].toString().trim().isNotEmpty) {
      nombre = json['nombre_completo'].toString();
    } else if (json['nombre'] != null &&
        json['nombre'].toString().trim().isNotEmpty) {
      nombre = json['nombre'].toString();
    } else if (json['email'] != null &&
        json['email'].toString().contains('@')) {
      nombre = json['email'].toString().split('@')[0];
    }

    String estado = 'activo';
    if (json['estado'] != null) {
      estado = json['estado'].toString();
    } else if (json['activo'] != null) {
      estado = json['activo'] == true ? 'activo' : 'inactivo';
    }

    DateTime creadoEn = DateTime.now();
    if (json['creado_en'] != null) {
      creadoEn =
          DateTime.tryParse(json['creado_en'].toString()) ?? DateTime.now();
    }

    return User(
      id: (json['id'] ?? 'operador-id').toString(),
      email: (json['email'] ?? 'operador@encuestas.com').toString(),
      rol: (json['rol'] ?? 'operador').toString(),
      creadoEn: creadoEn,
      tipo: (json['tipo'] ?? 'operador').toString(),
      nombre: nombre,
      telefono: (json['telefono'] ?? '').toString(),
      estado: estado,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'rol': rol,
      'creado_en': creadoEn.toIso8601String(),
      'tipo': tipo,
      'nombre': nombre,
      'telefono': telefono,
      'estado': estado,
    };
  }
}
