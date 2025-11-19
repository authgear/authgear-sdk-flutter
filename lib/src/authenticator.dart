class Authenticator {
  final DateTime createdAt;
  final DateTime updatedAt;
  final AuthenticatorType type;
  final AuthenticatorKind kind;
  final String? displayName;
  final String? email;
  final String? phone;

  Authenticator.fromJSON(dynamic json)
      : createdAt = DateTime.parse(json["created_at"]),
        updatedAt = DateTime.parse(json["updated_at"]),
        type = AuthenticatorTypeExtension.parse(json["type"]),
        kind = AuthenticatorKindExtension.parse(json["kind"]),
        displayName = json["display_name"],
        email = json["email"],
        phone = json["phone"];
}

enum AuthenticatorType {
  password,
  oobOtpEmail,
  oobOtpSms,
  totp,
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
      default:
        throw Exception("unknown authenticator type: $value");
    }
  }
}

enum AuthenticatorKind {
  primary,
  secondary,
}

extension AuthenticatorKindExtension on AuthenticatorKind {
  String get value {
    switch (this) {
      case AuthenticatorKind.primary:
        return "primary";
      case AuthenticatorKind.secondary:
        return "secondary";
    }
  }

  static AuthenticatorKind parse(String value) {
    switch (value) {
      case "primary":
        return AuthenticatorKind.primary;
      case "secondary":
        return AuthenticatorKind.secondary;
      default:
        throw Exception("unknown authenticator kind: $value");
    }
  }
}
