enum SessionState {
  unknown,
  noSession,
  authenticated,
}

enum SessionStateChangeReason {
  noToken,
  foundToken,
  authenticated,
  logout,
  invalid,
  clear,
}

enum PromptOption {
  none,
  login,
  consent,
  selectAccount,
}

extension PromptOptionExtension on PromptOption {
  String get value {
    switch (this) {
      case PromptOption.none:
        return "none";
      case PromptOption.login:
        return "login";
      case PromptOption.consent:
        return "consent";
      case PromptOption.selectAccount:
        return "select_account";
    }
  }
}

enum AuthenticationPage {
  login,
  signup,
}

enum SettingsPage {
  settings,
  identity,
}

extension SettingsPageExtension on SettingsPage {
  String get path {
    switch (this) {
      case SettingsPage.settings:
        return "/settings";
      case SettingsPage.identity:
        return "/settings/identity";
    }
  }
}

class UserInfo {
  final String sub;
  final bool isAnonymous;
  final bool isVerified;

  UserInfo.fromJSON(dynamic json)
      : sub = json["sub"],
        isAnonymous = json["https://authgear.com/claims/user/is_anonymous"],
        isVerified = json["https://authgear.com/claims/user/is_verified"];
}

class AuthenticateResult {
  final UserInfo userInfo;
  final String? state;

  AuthenticateResult({required this.userInfo, required this.state});
}

class ReauthenticateResult {
  final UserInfo userInfo;
  final String? state;

  ReauthenticateResult({required this.userInfo, required this.state});
}

class OIDCConfiguration {
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String userinfoEndpoint;
  final String revocationEndpoint;
  final String endSessionEndpoint;

  OIDCConfiguration.fromJSON(dynamic json)
      : authorizationEndpoint = json["authorization_endpoint"],
        tokenEndpoint = json["token_endpoint"],
        userinfoEndpoint = json["userinfo_endpoint"],
        revocationEndpoint = json["revocation_endpoint"],
        endSessionEndpoint = json["end_session_endpoint"];
}

class AppSessionTokenResponse {
  final String appSessionToken;
  final DateTime expireAt;

  AppSessionTokenResponse.fromJSON(dynamic json)
      : appSessionToken = json["app_session_token"],
        expireAt = DateTime.parse(json["expire_at"]);
}

class ChallengeResponse {
  final String token;
  final DateTime expireAt;

  ChallengeResponse.fromJSON(dynamic json)
      : token = json["token"],
        expireAt = DateTime.parse(json["expire_at"]);
}

abstract class AuthgearHttpClientDelegate {
  String? get accessToken;
  bool get shouldRefreshAccessToken;
  Future<void> refreshAccessToken();
}

enum BiometricAccessConstraintIOS {
  biometryAny,
  biometryCurrentSet,
  userPresence,
}

extension BiometricAccessConstraintIOSExtension
    on BiometricAccessConstraintIOS {
  String get value {
    return name;
  }
}

class BiometricOptionsIOS {
  final String localizedReason;
  final BiometricAccessConstraintIOS constraint;

  BiometricOptionsIOS({
    required this.localizedReason,
    required this.constraint,
  });

  Map<String, dynamic> toMap() {
    return {
      "localizedReason": localizedReason,
      "constraint": constraint.value,
    };
  }
}

enum BiometricAccessConstraintAndroid {
  biometricStrong,
  deviceCredential,
}

extension BiometricAccessConstraintAndroidExtension
    on BiometricAccessConstraintAndroid {
  String get value {
    switch (this) {
      case BiometricAccessConstraintAndroid.biometricStrong:
        return "BIOMETRIC_STRONG";
      case BiometricAccessConstraintAndroid.deviceCredential:
        return "DEVICE_CREDENTIAL";
    }
  }
}

class BiometricOptionsAndroid {
  final String title;
  final String subtitle;
  final String description;
  final String negativeButtonText;
  final List<BiometricAccessConstraintAndroid> constraint;
  final bool invalidatedByBiometricEnrollment;

  BiometricOptionsAndroid({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.negativeButtonText,
    required this.constraint,
    required this.invalidatedByBiometricEnrollment,
  });

  Map<String, dynamic> toMap() {
    return {
      "title": title,
      "subtitle": subtitle,
      "description": description,
      "negativeButtonText": negativeButtonText,
      "constraint": [for (var i in constraint) i.value],
      "invalidatedByBiometricEnrollment": invalidatedByBiometricEnrollment,
    };
  }
}
