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

class UserInfo {
  final String sub;
  final String iss;
  final bool isAnonymous;
  final bool isVerified;

  UserInfo.fromJSON(dynamic json)
      : sub = json["sub"],
        iss = json["iss"],
        isAnonymous = json["https://authgear.com/claims/user/is_anonymous"],
        isVerified = json["https://authgear.com/claims/user/is_verified"];
}

class AuthenticateResult {
  final UserInfo userInfo;
  final String? state;

  AuthenticateResult._({required this.userInfo, required this.state});
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
