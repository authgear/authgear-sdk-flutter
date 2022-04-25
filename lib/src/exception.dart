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
