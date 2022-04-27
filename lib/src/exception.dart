class AuthgearException implements Exception {
  final Exception? underlyingException;
  AuthgearException(this.underlyingException);
}

class CancelException extends AuthgearException {
  CancelException() : super(null);
}

class OAuthException extends AuthgearException {
  final String error;
  final String? errorDescription;
  final String? errorURI;
  final String? state;

  OAuthException({
    required this.error,
    this.errorDescription,
    this.errorURI,
    this.state,
  }) : super(null);
}

class ServerException extends AuthgearException {
  final String name;
  final String reason;
  final String message;
  final dynamic info;

  ServerException({
    required this.name,
    required this.reason,
    required this.message,
    required this.info,
  }) : super(null);
}

Exception decodeException(dynamic error) {
  if (error is Map) {
    final name = error["name"];
    final reason = error["reason"];
    final message = error["message"];
    final info = error["info"];
    if (name is String && reason is String && message is String) {
      return ServerException(
          name: name, reason: reason, message: message, info: info);
    }
  }

  if (error is Exception) {
    return error;
  }

  return Exception("$error");
}
