import 'dart:io' show Platform;
import 'package:flutter/services.dart' show PlatformException;

class AuthgearException implements Exception {
  final Exception? underlyingException;
  const AuthgearException(this.underlyingException);
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

class CancelException extends AuthgearException {
  const CancelException() : super(null);
}

class BiometricPrivateKeyNotFoundException extends AuthgearException {
  const BiometricPrivateKeyNotFoundException() : super(null);
}

class BiometricNotSupportedOrPermissionDeniedException
    extends AuthgearException {
  const BiometricNotSupportedOrPermissionDeniedException() : super(null);
}

class BiometricNoPasscodeException extends AuthgearException {
  const BiometricNoPasscodeException() : super(null);
}

class BiometricNoEnrollmentException extends AuthgearException {
  const BiometricNoEnrollmentException() : super(null);
}

class BiometricLockoutException extends AuthgearException {
  const BiometricLockoutException() : super(null);
}

const _cancelException = CancelException();
const _biometricPrivateKeyNotFoundException =
    BiometricPrivateKeyNotFoundException();
const _biometricNotSupportedOrPermissionDeniedException =
    BiometricNotSupportedOrPermissionDeniedException();
const _biometricNoPasscodeException = BiometricNoPasscodeException();
const _biometricNoEnrollmentException = BiometricNoEnrollmentException();
const _biometricLockoutException = BiometricLockoutException();

const _kLAErrorUserCancel = "-2";
const _kLAErrorPasscodeNotSet = "-5";
const _kLAErrorBiometryNotAvailable = "-6";
const _kLAErrorBiometryNotEnrolled = "-7";
const _kLAErrorBiometryLockout = "-8";

const _errSecUserCanceled = "-128";
const _errSecItemNotFound = "-25300";

const _BIOMETRIC_ERROR_HW_UNAVAILABLE = "BIOMETRIC_ERROR_HW_UNAVAILABLE";
const _BIOMETRIC_ERROR_NONE_ENROLLED = "BIOMETRIC_ERROR_NONE_ENROLLED";
const _BIOMETRIC_ERROR_NO_HARDWARE = "BIOMETRIC_ERROR_NO_HARDWARE";
const _BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED =
    "BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED";
const _BIOMETRIC_ERROR_UNSUPPORTED = "BIOMETRIC_ERROR_UNSUPPORTED";

const _ERROR_CANCELED = "ERROR_CANCELED";
const _ERROR_HW_NOT_PRESENT = "ERROR_HW_NOT_PRESENT";
const _ERROR_HW_UNAVAILABLE = "ERROR_HW_UNAVAILABLE";
const _ERROR_LOCKOUT = "ERROR_LOCKOUT";
const _ERROR_LOCKOUT_PERMANENT = "ERROR_LOCKOUT_PERMANENT";
const _ERROR_NEGATIVE_BUTTON = "ERROR_NEGATIVE_BUTTON";
const _ERROR_NO_BIOMETRICS = "ERROR_NO_BIOMETRICS";
const _ERROR_NO_DEVICE_CREDENTIAL = "ERROR_NO_DEVICE_CREDENTIAL";
const _ERROR_SECURITY_UPDATE_REQUIRED = "ERROR_SECURITY_UPDATE_REQUIRED";
const _ERROR_USER_CANCELED = "ERROR_USER_CANCELED";

class _Tuple<T1, T2> {
  final T1 t1;
  final T2 t2;
  const _Tuple(this.t1, this.t2);
}

const _exceptionMappings = [
  _Tuple(_isBiometricPrivateKeyNotFoundException,
      _biometricPrivateKeyNotFoundException),
  _Tuple(_isBiometricCancel, _cancelException),
  _Tuple(_isBiometricNotSupportedOrPermissionDeniedException,
      _biometricNotSupportedOrPermissionDeniedException),
  _Tuple(_isBiometricNoPasscodeException, _biometricNoPasscodeException),
  _Tuple(_isBiometricNoEnrollmentException, _biometricNoEnrollmentException),
  _Tuple(_isBiometricLockoutException, _biometricLockoutException),
  _Tuple(_isCancel, _cancelException),
];

Exception wrapException(PlatformException e) {
  for (var i in _exceptionMappings) {
    final matched = i.t1(e);
    if (matched) {
      return i.t2;
    }
  }
  return AuthgearException(e);
}

bool _isBiometricPrivateKeyNotFoundException(PlatformException e) {
  if (Platform.isIOS) {
    return e.code == _errSecItemNotFound;
  }
  if (Platform.isAndroid) {
    return e.code ==
        "android.security.keystore.KeyPermanentlyInvalidatedException";
  }
  return false;
}

bool _isBiometricCancel(PlatformException e) {
  if (Platform.isIOS) {
    return e.code == _kLAErrorUserCancel || e.code == _errSecUserCanceled;
  }
  if (Platform.isAndroid) {
    return e.code == _ERROR_CANCELED ||
        e.code == _ERROR_NEGATIVE_BUTTON ||
        e.code == _ERROR_USER_CANCELED;
  }
  return false;
}

bool _isBiometricNotSupportedOrPermissionDeniedException(PlatformException e) {
  if (Platform.isIOS) {
    return e.code == _kLAErrorBiometryNotAvailable;
  }
  if (Platform.isAndroid) {
    return e.code == _BIOMETRIC_ERROR_HW_UNAVAILABLE ||
        e.code == _BIOMETRIC_ERROR_NO_HARDWARE ||
        e.code == _BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED ||
        e.code == _BIOMETRIC_ERROR_UNSUPPORTED ||
        e.code == _ERROR_HW_NOT_PRESENT ||
        e.code == _ERROR_HW_UNAVAILABLE ||
        e.code == _ERROR_SECURITY_UPDATE_REQUIRED;
  }
  return false;
}

bool _isBiometricNoPasscodeException(PlatformException e) {
  if (Platform.isIOS) {
    return e.code == _kLAErrorPasscodeNotSet;
  }
  if (Platform.isAndroid) {
    return e.code == _ERROR_NO_DEVICE_CREDENTIAL;
  }
  return false;
}

bool _isBiometricNoEnrollmentException(PlatformException e) {
  if (Platform.isIOS) {
    return e.code == _kLAErrorBiometryNotEnrolled;
  }
  if (Platform.isAndroid) {
    return e.code == _BIOMETRIC_ERROR_NONE_ENROLLED ||
        e.code == _ERROR_NO_BIOMETRICS;
  }
  return false;
}

bool _isBiometricLockoutException(PlatformException e) {
  if (Platform.isIOS) {
    return e.code == _kLAErrorBiometryLockout;
  }
  if (Platform.isAndroid) {
    return e.code == _ERROR_LOCKOUT || e.code == _ERROR_LOCKOUT_PERMANENT;
  }
  return false;
}

bool _isCancel(PlatformException e) {
  return e.code == "CANCEL";
}
