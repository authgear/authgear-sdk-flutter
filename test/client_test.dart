import 'dart:math' show Random;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_authgear/src/type.dart';
import 'package:flutter_authgear/src/code_verifier.dart';
import 'package:flutter_authgear/src/client.dart';

void main() {
  test("OIDCAuthenticationRequest", () {
    final r = OIDCAuthenticationRequest(
      redirectURI: "http://host/path",
      responseType: "code",
      scope: ["openid", "email"],
      state: "state",
      prompt: [PromptOption.login],
      loginHint: "loginHint",
      uiLocales: ["en-US", "zh-HK"],
      idTokenHint: "idTokenHint",
      maxAge: 1000000000000000000,
      page: AuthenticationPage.login,
      suppressIDPSessionCookie: true,
    );

    final rng = Random(0);
    final codeVerifier = CodeVerifier(rng);
    var u = Uri.https("localhost", "/");
    u = u.replace(
        queryParameters: r.toQueryParameters(
            clientID: "clientID", codeVerifier: codeVerifier));
    expect(u.toString(),
        "https://localhost/?response_type=code&client_id=clientID&redirect_uri=http%3A%2F%2Fhost%2Fpath&scope=openid+email&code_challenge_method=S256&code_challenge=wwOl-gkE1Q8-wqEVWep4uYe2wYR7k73M9JMXUjtSx80&state=state&prompt=login&login_hint=loginHint&id_token_hint=idTokenHint&ui_locales=en-US+zh-HK&max_age=1000000000000000000&x_page=login&x_suppress_idp_session_cookie=true");
  });
}
