class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? fieldErrors;

  ApiException(this.message, {this.statusCode, this.fieldErrors});

  @override
  String toString() => message;
}

/// Convertit toute erreur (réseau, parsing, état, etc.) en message explicite
/// compréhensible par l'utilisateur, sans jamais exposer de détails techniques.
String userFriendlyError(Object? error) {
  if (error is ApiException) {
    return sanitizeErrorMessage(error.message);
  }
  if (error is String) {
    return sanitizeErrorMessage(error);
  }
  return 'Une erreur inattendue est survenue. Veuillez réessayer.';
}

String sanitizeErrorMessage(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return 'Une erreur est survenue. Veuillez réessayer.';
  }
  final lower = raw.toLowerCase();
  const technicalMarkers = [
    'exception',
    'type \'',
    'is not a subtype',
    'formatexception',
    'socketexception',
    'httpexception',
    'dioexception',
    'null check operator',
    'stacktrace',
    'stack trace',
    'java.',
    'org.springframework',
    '<html',
    '<!doctype',
  ];
  for (final marker in technicalMarkers) {
    if (lower.contains(marker)) {
      return 'Une erreur technique est survenue. Veuillez réessayer plus tard.';
    }
  }
  return raw;
}

class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json)? fromJsonT,
  ) {
    final rawData = json['data'];
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      data: rawData != null && fromJsonT != null ? fromJsonT(rawData) : rawData as T?,
    );
  }
}

