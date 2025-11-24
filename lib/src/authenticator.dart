class Authenticator {
  final DateTime createdAt;
  final DateTime updatedAt;
  final AuthenticatorType type;
  final AuthenticatorKind kind;

  Authenticator.fromJSON(dynamic json)
      : createdAt = DateTime.parse(json["created_at"]),
        updatedAt = DateTime.parse(json["updated_at"]),
        type = AuthenticatorTypeExtension.parse(json["type"]),
        kind = AuthenticatorKindExtension.parse(json["kind"]);
}

enum AuthenticatorType {
  password,
  oobOtpEmail,
  oobOtpSms,
  totp,
  passkey,
  unknown,
}

extension AuthenticatorTypeExtension on AuthenticatorType {
  String get value {
    switch (this) {
      case AuthenticatorType.password:
        return "password";
      case AuthenticatorType.oobOtpEmail:
        return "oob_otp_email";
      case AuthenticatorType.oobOtpSms:
        return "oob_otp_sms";
      case AuthenticatorType.totp:
        return "totp";
      case AuthenticatorType.passkey:
        return "passkey";
      case AuthenticatorType.unknown:
        return "unknown";
    }
  }

  static AuthenticatorType parse(String value) {
    switch (value) {
      case "password":
        return AuthenticatorType.password;
      case "oob_otp_email":
        return AuthenticatorType.oobOtpEmail;
      case "oob_otp_sms":
        return AuthenticatorType.oobOtpSms;
      case "totp":
        return AuthenticatorType.totp;
      case "passkey":
        return AuthenticatorType.passkey;
      default:
        return AuthenticatorType.unknown;
    }
  }
}

enum AuthenticatorKind {
  primary,
  secondary,
  unknown,
}

extension AuthenticatorKindExtension on AuthenticatorKind {
  String get value {
    switch (this) {
      case AuthenticatorKind.primary:
        return "primary";
      case AuthenticatorKind.secondary:
        return "secondary";
      case AuthenticatorKind.unknown:
        return "unknown";
    }
  }

  static AuthenticatorKind parse(String value) {
    switch (value) {
      case "primary":
        return AuthenticatorKind.primary;
      case "secondary":
        return AuthenticatorKind.secondary;
      default:
        return AuthenticatorKind.unknown;
    }
  }
}
