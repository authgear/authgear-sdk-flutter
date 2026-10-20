import 'dart:convert' show jsonDecode;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_authgear/src/type.dart';
import 'package:flutter_authgear/src/client.dart';

void main() {
  test("OIDCAuthenticationRequest", () {
    final r = OIDCAuthenticationRequest(
      clientID: "clientID",
      redirectURI: "http://host/path",
      responseType: ResponseType.code,
      scope: ["openid", "email"],
      isSsoEnabled: false,
      codeChallenge: "codeChallenge",
      state: "state",
      prompt: [PromptOption.login],
      loginHint: "loginHint",
      uiLocales: ["en-US", "zh-HK"],
      idTokenHint: "idTokenHint",
      maxAge: 1000000000000000000,
      page: AuthenticationPage.login,
      wechatRedirectURI: "wechatRedirectURI",
      oauthProviderAlias: "google",
    );

    var u = Uri.https("localhost", "/");
    u = u.replace(queryParameters: r.toQueryParameters());
    expect(u.toString(),
        "https://localhost/?response_type=code&client_id=clientID&redirect_uri=http%3A%2F%2Fhost%2Fpath&scope=openid+email&code_challenge_method=S256&code_challenge=codeChallenge&state=state&prompt=login&login_hint=loginHint&id_token_hint=idTokenHint&ui_locales=en-US+zh-HK&max_age=1000000000000000000&x_page=login&x_suppress_idp_session_cookie=true&x_sso_enabled=false&x_oauth_provider_alias=google&x_wechat_redirect_uri=wechatRedirectURI");
  });

  test("OIDCAuthenticationRequest with resource", () {
    final r = OIDCAuthenticationRequest(
      clientID: "clientID",
      redirectURI: "http://host/path",
      responseType: ResponseType.code,
      isSsoEnabled: false,
      resource: "https://api.example.com/",
    );

    expect(r.toQueryParameters()["resource"], "https://api.example.com/");
  });

  test("OIDCAuthenticationRequest without resource", () {
    final r = OIDCAuthenticationRequest(
      clientID: "clientID",
      redirectURI: "http://host/path",
      responseType: ResponseType.code,
      isSsoEnabled: false,
    );

    expect(r.toQueryParameters().containsKey("resource"), false);
  });

  test("BiometricRequest with scope and resource", () {
    final q = BiometricRequest(
      clientID: "clientID",
      jwt: "jwt",
      scope: ["openid", "offline_access"],
      resource: "https://api.example.com/",
    ).toQueryParameters();
    expect(q["scope"], "openid offline_access");
    expect(q["resource"], "https://api.example.com/");
  });

  test("BiometricRequest without resource", () {
    final q =
        BiometricRequest(clientID: "clientID", jwt: "jwt").toQueryParameters();
    expect(q.containsKey("resource"), false);
    expect(q.containsKey("scope"), false);
  });

  test("AnonymousRequest with scope and resource", () {
    final q = AnonymousRequest(
      clientID: "clientID",
      jwt: "jwt",
      scope: ["openid", "offline_access"],
      resource: "https://api.example.com/",
    ).toQueryParameters();
    expect(q["scope"], "openid offline_access");
    expect(q["resource"], "https://api.example.com/");
  });

  test("OIDCTokenRequest with resource", () {
    final q = OIDCTokenRequest(
      grantType: GrantType.tokenExchange,
      clientID: "clientID",
      resource: "https://api.example.com/",
    ).toQueryParameters();
    expect(q["resource"], "https://api.example.com/");
  });

  test("OIDCTokenRequest", () {
    final r = OIDCTokenRequest(
      grantType: GrantType.authorizationCode,
      clientID: "clientID",
      code: "code",
      redirectURI: "http://host/path",
      codeVerifier: "codeVerifier",
      refreshToken: "refreshToken",
      accessToken: "accessToken",
      jwt: "jwt",
      xDeviceInfo: "xDeviceInfo",
    );

    expect(r.toQueryParameters(), {
      "grant_type": "authorization_code",
      "client_id": "clientID",
      "code": "code",
      "redirect_uri": "http://host/path",
      "code_verifier": "codeVerifier",
      "refresh_token": "refreshToken",
      "access_token": "accessToken",
      "jwt": "jwt",
      "x_device_info": "xDeviceInfo",
    });
  });

  test("OIDCTokenResponse", () {
    const jsonStr =
        '{"token_type": "bearer", "refresh_token": "refreshToken", "access_token": "accessToken", "expires_in": 300}';
    final json = jsonDecode(jsonStr);
    final r = OIDCTokenResponse.fromJSON(json);
    expect(r.refreshToken, "refreshToken");
    expect(r.accessToken, "accessToken");
    expect(r.expiresIn, 300);
  });
}
