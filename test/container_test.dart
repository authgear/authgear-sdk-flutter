import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_authgear/src/code_verifier.dart';
import 'package:flutter_authgear/src/client.dart';
import 'package:flutter_authgear/src/container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Authgear constructor', () async {
    var _ = Authgear(clientID: "clientID", endpoint: "http://localhost:3000");
  });

  test('StreamController.broadcast can have multiple subscribers', () async {
    final controller = StreamController<int>.broadcast(sync: true);
    final stream = controller.stream;

    int total = 0;

    stream.listen((data) {
      total += data;
    });
    stream.listen((data) {
      total += data;
    });

    controller.add(1);
    controller.add(2);

    expect(total, 6);
  });

  group('AuthenticateOptions scopes', () {
    List<String>? requestScope({
      bool preAuthenticatedURLEnabled = false,
      List<String>? scopes,
    }) {
      final options = AuthenticateOptions(
        redirectURI: "http://host/path",
        isSsoEnabled: false,
        preAuthenticatedURLEnabled: preAuthenticatedURLEnabled,
        scopes: scopes,
      );
      return options
          .toRequest("clientID", CodeVerifier(Random.secure()), null)
          .scope;
    }

    test('requests the scopes required by the SDK', () {
      expect(requestScope(), [
        "openid",
        "offline_access",
        "https://authgear.com/scopes/full-access",
      ]);
    });

    test('merges additional scopes after the scopes required by the SDK', () {
      expect(
        requestScope(
          preAuthenticatedURLEnabled: true,
          scopes: ["email", "profile"],
        ),
        [
          "openid",
          "offline_access",
          "https://authgear.com/scopes/full-access",
          "device_sso",
          "https://authgear.com/scopes/pre-authenticated-url",
          "email",
          "profile",
        ],
      );
    });

    test('never drops or duplicates the scopes required by the SDK', () {
      expect(requestScope(scopes: ["email", "openid", "email"]), [
        "openid",
        "offline_access",
        "https://authgear.com/scopes/full-access",
        "email",
      ]);
    });
  });

  group('AuthenticateOptions configure defaults', () {
    OIDCAuthenticationRequest toRequest({
      String? resource,
      List<String>? scopes,
    }) {
      final options = AuthenticateOptions(
        redirectURI: "http://host/path",
        isSsoEnabled: false,
        resource: resource,
        scopes: scopes,
      );
      return options.toRequest(
        "clientID",
        CodeVerifier(Random.secure()),
        null,
        defaultResource: "https://default.example.com/",
        defaultScopes: ["default"],
      );
    }

    test('uses the defaults when the call gives none', () {
      final r = toRequest();
      expect(r.resource, "https://default.example.com/");
      expect(r.scope, [
        "openid",
        "offline_access",
        "https://authgear.com/scopes/full-access",
        "default",
      ]);
    });

    test('replaces the defaults with the values of the call', () {
      final r = toRequest(
        resource: "https://call.example.com/",
        scopes: ["call"],
      );
      expect(r.resource, "https://call.example.com/");
      expect(r.scope, [
        "openid",
        "offline_access",
        "https://authgear.com/scopes/full-access",
        "call",
      ]);
    });
  });

  group('getAnonymousScopes', () {
    test('sends no scope when none is given', () {
      expect(getAnonymousScopes(null), null);
    });

    test('merges the given scopes with the scopes required by the SDK', () {
      expect(getAnonymousScopes(["email"]), [
        "openid",
        "offline_access",
        "https://authgear.com/scopes/full-access",
        "email",
      ]);
    });
  });
}
