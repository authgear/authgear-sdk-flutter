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

enum ColorScheme {
  light,
  dark,
}

enum ResponseType {
  code,
  settingsAction,
  none,
  appInitiatedSSOToWebToken,
}

extension ResponseTypeExtension on ResponseType {
  String get value {
    switch (this) {
      case ResponseType.code:
        return "code";
      case ResponseType.settingsAction:
        return "urn:authgear:params:oauth:response-type:settings-action";
      case ResponseType.none:
        return "none";
      case ResponseType.appInitiatedSSOToWebToken:
        return "urn:authgear:params:oauth:response-type:app_initiated_sso_to_web token";
    }
  }
}

enum ResponseMode {
  cookie,
}

extension ResponseModeExtension on ResponseMode {
  String get value {
    switch (this) {
      case ResponseMode.cookie:
        return "cookie";
    }
  }
}

enum GrantType {
  authorizationCode,
  refreshToken,
  anonymous,
  biometric,
  idToken,
  app2app,
  settingsAction,
  tokenExchange,
}

extension GrantTypeExtension on GrantType {
  String get value {
    switch (this) {
      case GrantType.authorizationCode:
        return "authorization_code";
      case GrantType.refreshToken:
        return "refresh_token";
      case GrantType.anonymous:
        return "urn:authgear:params:oauth:grant-type:anonymous-request";
      case GrantType.biometric:
        return "urn:authgear:params:oauth:grant-type:biometric-request";
      case GrantType.idToken:
        return "urn:authgear:params:oauth:grant-type:id-token";
      case GrantType.app2app:
        return "urn:authgear:params:oauth:grant-type:app2app-request";
      case GrantType.settingsAction:
        return "urn:authgear:params:oauth:grant-type:settings-action";
      case GrantType.tokenExchange:
        return "urn:ietf:params:oauth:grant-type:token-exchange";
    }
  }
}

enum RequestedTokenType {
  appInitiatedSSOToWebToken,
}

extension RequestedTokenTypeExtension on RequestedTokenType {
  String get value {
    switch (this) {
      case RequestedTokenType.appInitiatedSSOToWebToken:
        return "urn:authgear:params:oauth:token-type:app-initiated-sso-to-web-token";
    }
  }
}

enum SubjectTokenType {
  idToken,
}

extension SubjectTokenTypeExtension on SubjectTokenType {
  String get value {
    switch (this) {
      case SubjectTokenType.idToken:
        return "urn:ietf:params:oauth:token-type:id_token";
    }
  }
}

enum ActorTokenType {
  deviceSecret,
}

extension ActorTokenTypeExtension on ActorTokenType {
  String get value {
    switch (this) {
      case ActorTokenType.deviceSecret:
        return "urn:x-oath:params:oauth:token-type:device-secret";
    }
  }
}

enum SettingsAction { changePassword, deleteAccount }

extension SettingsActionExtension on SettingsAction {
  String get value {
    switch (this) {
      case SettingsAction.changePassword:
        return "change_password";
      case SettingsAction.deleteAccount:
        return "delete_account";
    }
  }
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

class UserInfoAddress {
  final String? formatted;
  final String? streetAddress;
  final String? locality;
  final String? region;
  final String? postalCode;
  final String? country;

  UserInfoAddress.fromJSON(dynamic json)
      : formatted = json["formatted"],
        streetAddress = json["street_address"],
        locality = json["locality"],
        region = json["region"],
        postalCode = json["postal_code"],
        country = json["country"];
}

List<String>? parseRoles(dynamic roles) {
  if (roles is List) {
    return roles.cast<String>();
  }
  return null;
}

class UserInfo {
  final String sub;
  final bool isAnonymous;
  final bool isVerified;
  final bool canReauthenticate;
  final List<String>? roles;

  final Map<String, dynamic> raw;
  final Map<String, dynamic> customAttributes;

  final String? email;
  final bool? emailVerified;
  final String? phoneNumber;
  final bool? phoneNumberVerified;
  final String? preferredUsername;
  final String? familyName;
  final String? givenName;
  final String? middleName;
  final String? name;
  final String? nickname;
  final String? picture;
  final String? profile;
  final String? website;
  final String? gender;
  final String? birthdate;
  final String? zoneinfo;
  final String? locale;
  final UserInfoAddress? address;

  UserInfo.fromJSON(dynamic json)
      : sub = json["sub"],
        isAnonymous = json["https://authgear.com/claims/user/is_anonymous"],
        isVerified = json["https://authgear.com/claims/user/is_verified"],
        canReauthenticate =
            json["https://authgear.com/claims/user/can_reauthenticate"],
        roles = parseRoles(json["https://authgear.com/claims/user/roles"]),
        raw = json,
        customAttributes = json["custom_attributes"] ?? {},
        email = json["email"],
        emailVerified = json["email_verified"],
        phoneNumber = json["phone_number"],
        phoneNumberVerified = json["phone_number_verified"],
        preferredUsername = json["preferred_username"],
        familyName = json["family_name"],
        givenName = json["given_name"],
        middleName = json["middle_name"],
        name = json["name"],
        nickname = json["nickname"],
        picture = json["picture"],
        profile = json["profile"],
        website = json["website"],
        gender = json["gender"],
        birthdate = json["birthdate"],
        zoneinfo = json["zoneinfo"],
        locale = json["locale"],
        address = json["address"] != null
            ? UserInfoAddress.fromJSON(json["address"])
            : null;
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

enum BiometricLAPolicy {
  deviceOwnerAuthenticationWithBiometrics,
  deviceOwnerAuthentication,
}

extension BiometricLAPolicyExtension on BiometricLAPolicy {
  String get value {
    return name;
  }
}

class BiometricOptionsIOS {
  final String localizedReason;
  final BiometricAccessConstraintIOS constraint;
  final BiometricLAPolicy policy;

  BiometricOptionsIOS({
    required this.localizedReason,
    required this.constraint,
    required this.policy,
  });

  Map<String, dynamic> toMap() {
    return {
      "localizedReason": localizedReason,
      "constraint": constraint.value,
      "policy": policy.value,
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
