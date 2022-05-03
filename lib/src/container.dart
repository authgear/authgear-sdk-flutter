import 'dart:math' show Random;
import 'dart:async' show StreamController;
import 'dart:convert' show jsonEncode, utf8;
import 'package:http/http.dart' show Client;

import 'storage.dart';
import 'client.dart';
import 'type.dart';
import 'code_verifier.dart';
import 'exception.dart';
import 'base64.dart';
import 'id_token.dart';
import 'native.dart' as native;

class SessionStateChangeEvent {
  final SessionStateChangeReason reason;
  final Authgear instance;

  SessionStateChangeEvent({required this.instance, required this.reason});
}

final _rng = Random.secure();

const _expiresInPercentage = 0.9;

Future<String> _getXDeviceInfo() async {
  final deviceInfo = await native.getDeviceInfo();
  final deviceInfoJSON = jsonEncode(deviceInfo);
  final deviceInfoJSONBytes = utf8.encode(deviceInfoJSON);
  final xDeviceInfo = base64UrlEncode(deviceInfoJSONBytes);
  return xDeviceInfo;
}

// It seems that dart's convention of iOS' delegate is individual property of write-only function
// See https://api.dart.dev/stable/2.16.2/dart-io/HttpClient/authenticate.html
class Authgear implements AuthgearHttpClientDelegate {
  final String clientID;
  final String endpoint;
  final String name;
  final bool shareSessionWithSystemBrowser;

  final TokenStorage _tokenStorage;
  final ContainerStorage _storage;
  late final APIClient _apiClient;

  SessionState _sessionStateRaw = SessionState.unknown;
  SessionState get sessionState => _sessionStateRaw;
  final StreamController<SessionStateChangeEvent>
      _sessionStateStreamController = StreamController.broadcast();
  Stream<SessionStateChangeEvent> get onSessionStateChange =>
      _sessionStateStreamController.stream;

  String? _accessToken;
  @override
  String? get accessToken => _accessToken;
  String? _refreshToken;
  DateTime? _expireAt;

  String? _idToken;
  String? get idTokenHint => _idToken;
  bool get canReauthenticate {
    final idToken = _idToken;
    if (idToken == null) {
      return false;
    }
    final payload = decodeIDToken(idToken);
    final can = payload["https://authgear.com/claims/user/can_reauthenticate"];
    return can is bool && can == true;
  }

  DateTime? get authTime {
    final idToken = _idToken;
    if (idToken == null) {
      return null;
    }
    final payload = decodeIDToken(idToken);
    final authTimeValue = payload["auth_time"];
    if (authTimeValue is num) {
      return DateTime.fromMillisecondsSinceEpoch(authTimeValue.toInt() * 1000,
          isUtc: true);
    }
    return null;
  }

  Authgear({
    required this.clientID,
    required this.endpoint,
    this.name = "default",
    this.shareSessionWithSystemBrowser = false,
    TokenStorage? tokenStorage,
  })  : _tokenStorage = tokenStorage ?? PersistentTokenStorage(),
        _storage = PersistentContainerStorage() {
    final plainHttpClient = Client();
    final authgearHttpClient = AuthgearHttpClient(this, plainHttpClient);
    _apiClient = APIClient(
      endpoint: endpoint,
      plainHttpClient: plainHttpClient,
      authgearHttpClient: authgearHttpClient,
    );
  }

  Future<void> configure() async {
    _refreshToken = await _tokenStorage.getRefreshToken(name);
    final sessionState = _refreshToken == null
        ? SessionState.noSession
        : SessionState.authenticated;
    _setSessionState(sessionState, SessionStateChangeReason.foundToken);
  }

  void _setSessionState(SessionState s, SessionStateChangeReason r) {
    _sessionStateRaw = s;
    _sessionStateStreamController
        .add(SessionStateChangeEvent(instance: this, reason: r));
  }

  Future<UserInfo> authenticate({
    required String redirectURI,
    List<PromptOption>? prompt,
    List<String>? uiLocales,
    AuthenticationPage? page,
  }) async {
    final codeVerifier = CodeVerifier(_rng);
    final oidcRequest = OIDCAuthenticationRequest(
      clientID: clientID,
      redirectURI: redirectURI,
      responseType: "code",
      scope: [
        "openid",
        "offline_access",
        "https://authgear.com/scopes/full-access",
      ],
      codeChallenge: codeVerifier.codeChallenge,
      prompt: prompt,
      uiLocales: uiLocales,
      page: page,
      suppressIDPSessionCookie: !shareSessionWithSystemBrowser,
    );
    final config = await _apiClient.fetchOIDCConfiguration();
    final authenticationURL = Uri.parse(config.authorizationEndpoint)
        .replace(queryParameters: oidcRequest.toQueryParameters());
    final resultURL = await native.authenticate(
      url: authenticationURL.toString(),
      redirectURI: redirectURI,
      preferEphemeral: !shareSessionWithSystemBrowser,
    );
    final xDeviceInfo = await _getXDeviceInfo();
    return await _finishAuthentication(
        url: Uri.parse(resultURL),
        redirectURI: redirectURI,
        codeVerifier: codeVerifier,
        xDeviceInfo: xDeviceInfo);
  }

  Future<UserInfo> reauthenticate({
    required String redirectURI,
    int maxAge = 0,
    List<String>? uiLocales,
    BiometricOptionsIOS? biometricIOS,
    BiometricOptionsAndroid? biometricAndroid,
  }) async {
    final biometricEnabled = await isBiometricEnabled();
    if (biometricEnabled && biometricIOS != null && biometricAndroid != null) {
      return await authenticateBiometric(
        ios: biometricIOS,
        android: biometricAndroid,
      );
    }

    final codeVerifier = CodeVerifier(_rng);
    final oidcRequest = OIDCAuthenticationRequest(
      clientID: clientID,
      redirectURI: redirectURI,
      responseType: "code",
      scope: [
        "openid",
        "https://authgear.com/scopes/full-access",
      ],
      codeChallenge: codeVerifier.codeChallenge,
      uiLocales: uiLocales,
      idTokenHint: idTokenHint,
      maxAge: maxAge,
      suppressIDPSessionCookie: !shareSessionWithSystemBrowser,
    );
    final config = await _apiClient.fetchOIDCConfiguration();
    final authenticationURL = Uri.parse(config.authorizationEndpoint)
        .replace(queryParameters: oidcRequest.toQueryParameters());
    final resultURL = await native.authenticate(
      url: authenticationURL.toString(),
      redirectURI: redirectURI,
      preferEphemeral: !shareSessionWithSystemBrowser,
    );
    final xDeviceInfo = await _getXDeviceInfo();
    return await _finishReauthentication(
        url: Uri.parse(resultURL),
        redirectURI: redirectURI,
        codeVerifier: codeVerifier,
        xDeviceInfo: xDeviceInfo);
  }

  Future<UserInfo> getUserInfo() async {
    return _apiClient.getUserInfo();
  }

  Future<void> openURL(String url) async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) {
      throw Exception("openURL requires authenticated user");
    }

    final appSessionTokenResp =
        await _apiClient.getAppSessionToken(refreshToken);

    final loginHint =
        Uri.parse("https://authgear.com/login_hint").replace(queryParameters: {
      "type": "app_session_token",
      "app_session_token": appSessionTokenResp.appSessionToken,
    }).toString();

    final oidcRequest = OIDCAuthenticationRequest(
      clientID: clientID,
      redirectURI: url,
      responseType: "none",
      scope: [
        "openid",
        "offline_access",
        "https://authgear.com/scopes/full-access",
      ],
      prompt: [PromptOption.none],
      loginHint: loginHint,
    );
    final config = await _apiClient.fetchOIDCConfiguration();
    final targetURL = Uri.parse(config.authorizationEndpoint)
        .replace(queryParameters: oidcRequest.toQueryParameters());
    await native.openURL(targetURL.toString());
  }

  Future<void> open(SettingsPage page) async {
    final url = Uri.parse(endpoint).replace(path: page.path).toString();
    return openURL(url);
  }

  Future<void> refreshIDToken() async {
    if (shouldRefreshAccessToken) {
      await refreshAccessToken();
    }

    final tokenRequest = OIDCTokenRequest(
      grantType: "urn:authgear:params:oauth:grant-type:id-token",
      clientID: clientID,
      accessToken: accessToken,
    );

    final tokenResponse = await _apiClient.sendTokenRequest(tokenRequest,
        includeAccessToken: true);
    final idToken = tokenResponse.idToken;
    if (idToken != null) {
      _idToken = idToken;
    }
  }

  Future<void> logout({bool force = false}) async {
    final refreshToken = _refreshToken;
    if (refreshToken != null) {
      try {
        await _apiClient.revoke(refreshToken);
      } on Exception {
        if (!force) {
          rethrow;
        }
      }
    }
    await _clearSession(SessionStateChangeReason.logout);
  }

  Client wrapHttpClient(Client inner) {
    return AuthgearHttpClient(this, inner);
  }

  @override
  bool get shouldRefreshAccessToken {
    if (_refreshToken == null) {
      return false;
    }
    if (_accessToken == null) {
      return true;
    }
    final expireAt = _expireAt;
    if (expireAt == null) {
      return true;
    }
    final now = DateTime.now().toUtc();
    if (expireAt.compareTo(now) < 0) {
      return true;
    }
    return false;
  }

  @override
  Future<void> refreshAccessToken() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) {
      await _clearSession(SessionStateChangeReason.noToken);
      return;
    }

    final xDeviceInfo = await _getXDeviceInfo();
    final tokenRequest = OIDCTokenRequest(
      grantType: "refresh_token",
      clientID: clientID,
      refreshToken: refreshToken,
      xDeviceInfo: xDeviceInfo,
    );
    try {
      final tokenResponse = await _apiClient.sendTokenRequest(tokenRequest);
      await _persistTokenResponse(
          tokenResponse, SessionStateChangeReason.foundToken);
    } on OAuthException catch (e) {
      if (e.error == "invalid_grant") {
        await _clearSession(SessionStateChangeReason.invalid);
        return;
      }
      rethrow;
    }
  }

  Future<void> checkBiometricSupported({
    required BiometricOptionsIOS ios,
    required BiometricOptionsAndroid android,
  }) async {
    await native.checkBiometricSupported(ios: ios, android: android);
  }

  Future<void> enableBiometric({
    required BiometricOptionsIOS ios,
    required BiometricOptionsAndroid android,
  }) async {
    final kid = await native.generateUUID();
    final deviceInfo = await native.getDeviceInfo();
    final challengeResponse =
        await _apiClient.getChallenge("biometric_request");
    final now = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
    final payload = {
      "iat": now,
      "exp": now + 300,
      "challenge": challengeResponse.token,
      "action": "setup",
      "device_info": deviceInfo,
    };
    final jwt = await native.createBiometricPrivateKey(
      kid: kid,
      payload: payload,
      ios: ios,
      android: android,
    );
    await _apiClient.sendSetupBiometricRequest(BiometricRequest(
      clientID: clientID,
      jwt: jwt,
    ));
    await _storage.setBiometricKeyID(name, kid);
  }

  Future<bool> isBiometricEnabled() async {
    final keyID = await _storage.getBiometricKeyID(name);
    return keyID != null;
  }

  Future<void> disableBiometric() async {
    final keyID = await _storage.getBiometricKeyID(name);
    if (keyID != null) {
      await native.removeBiometricPrivateKey(keyID);
      await _storage.delBiometricKeyID(name);
    }
  }

  Future<UserInfo> authenticateBiometric({
    required BiometricOptionsIOS ios,
    required BiometricOptionsAndroid android,
  }) async {
    final kid = await _storage.getBiometricKeyID(name);
    if (kid == null) {
      throw Exception("biometric is not enabled");
    }

    final deviceInfo = await native.getDeviceInfo();
    final challengeResponse =
        await _apiClient.getChallenge("biometric_request");
    final now = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
    final payload = {
      "iat": now,
      "exp": now + 300,
      "challenge": challengeResponse.token,
      "action": "authenticate",
      "device_info": deviceInfo,
    };

    try {
      final jwt = await native.signWithBiometricPrivateKey(
        kid: kid,
        payload: payload,
        ios: ios,
        android: android,
      );
      final tokenResponse =
          await _apiClient.sendAuthenticateBiometricRequest(BiometricRequest(
        clientID: clientID,
        jwt: jwt,
      ));
      await _persistTokenResponse(
          tokenResponse, SessionStateChangeReason.authenticated);
      final userInfo = await _apiClient.getUserInfo();
      return userInfo;
    } on BiometricPrivateKeyNotFoundException {
      await disableBiometric();
      rethrow;
    } on OAuthException catch (e) {
      if (e.error == "invalid_grant" &&
          e.errorDescription == "InvalidCredentials") {
        await disableBiometric();
      }
      rethrow;
    }
  }

  Future<UserInfo> promoteAnonymousUser({
    required String redirectURI,
    List<String>? uiLocales,
  }) async {
    final kid = await _storage.getAnonymousKeyID(name);
    if (kid == null) {
      throw Exception("anonymous kid not found");
    }
    final challengeResponse =
        await _apiClient.getChallenge("anonymous_request");
    final now = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
    final payload = {
      "iat": now,
      "exp": now + 300,
      "challenge": challengeResponse.token,
      "action": "promote",
    };
    final jwt = await native.signWithAnonymousPrivateKey(
      kid: kid,
      payload: payload,
    );
    final loginHint =
        Uri.parse("https://authgear.com/login_hint").replace(queryParameters: {
      "type": "anonymous",
      "jwt": jwt,
    }).toString();

    final codeVerifier = CodeVerifier(_rng);
    final oidcRequest = OIDCAuthenticationRequest(
      clientID: clientID,
      redirectURI: redirectURI,
      responseType: "code",
      scope: [
        "openid",
        "offline_access",
        "https://authgear.com/scopes/full-access",
      ],
      codeChallenge: codeVerifier.codeChallenge,
      prompt: [PromptOption.login],
      loginHint: loginHint,
      uiLocales: uiLocales,
      suppressIDPSessionCookie: !shareSessionWithSystemBrowser,
    );
    final config = await _apiClient.fetchOIDCConfiguration();
    final authenticationURL = Uri.parse(config.authorizationEndpoint)
        .replace(queryParameters: oidcRequest.toQueryParameters());
    final resultURL = await native.authenticate(
      url: authenticationURL.toString(),
      redirectURI: redirectURI,
      preferEphemeral: !shareSessionWithSystemBrowser,
    );
    final xDeviceInfo = await _getXDeviceInfo();
    final userInfo = await _finishAuthentication(
        url: Uri.parse(resultURL),
        redirectURI: redirectURI,
        codeVerifier: codeVerifier,
        xDeviceInfo: xDeviceInfo);
    await _disableAnonymous();
    await disableBiometric();
    return userInfo;
  }

  Future<UserInfo> authenticateAnonymously() async {
    final kid = await _storage.getAnonymousKeyID(name);
    if (kid == null) {
      return _authenticateAnonymouslyCreate();
    }
    return _authenticateAnonymouslyExisting(kid);
  }

  Future<UserInfo> _authenticateAnonymouslyCreate() async {
    final challengeResponse =
        await _apiClient.getChallenge("anonymous_request");
    final kid = await native.generateUUID();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
    final payload = {
      "iat": now,
      "exp": now + 300,
      "challenge": challengeResponse.token,
      "action": "auth",
    };
    final jwt = await native.createAnonymousPrivateKey(
      kid: kid,
      payload: payload,
    );
    final tokenResponse =
        await _apiClient.sendAuthenticateAnonymousRequest(AnonymousRequest(
      clientID: clientID,
      jwt: jwt,
    ));
    await _persistTokenResponse(
        tokenResponse, SessionStateChangeReason.authenticated);
    final userInfo = await _apiClient.getUserInfo();
    await _storage.setAnonymousKeyID(name, kid);
    await disableBiometric();
    return userInfo;
  }

  Future<UserInfo> _authenticateAnonymouslyExisting(String kid) async {
    final challengeResponse =
        await _apiClient.getChallenge("anonymous_request");
    final now = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
    final payload = {
      "iat": now,
      "exp": now + 300,
      "challenge": challengeResponse.token,
      "action": "auth",
    };
    final jwt = await native.signWithAnonymousPrivateKey(
      kid: kid,
      payload: payload,
    );
    final tokenResponse =
        await _apiClient.sendAuthenticateAnonymousRequest(AnonymousRequest(
      clientID: clientID,
      jwt: jwt,
    ));
    await _persistTokenResponse(
        tokenResponse, SessionStateChangeReason.authenticated);
    final userInfo = await _apiClient.getUserInfo();
    await disableBiometric();
    return userInfo;
  }

  Future<void> _disableAnonymous() async {
    final kid = await _storage.getAnonymousKeyID(name);
    if (kid != null) {
      await native.removeAnonymousPrivateKey(kid);
      await _storage.delAnonymousKeyID(name);
    }
  }

  Future<void> _clearSession(SessionStateChangeReason reason) async {
    await _tokenStorage.delRefreshToken(name);
    _idToken = null;
    _accessToken = null;
    _refreshToken = null;
    _expireAt = null;
    _setSessionState(SessionState.noSession, reason);
  }

  Future<OIDCTokenResponse> _exchangeCode({
    required Uri url,
    required String redirectURI,
    required CodeVerifier codeVerifier,
    required String xDeviceInfo,
  }) async {
    final queryParameters = url.queryParameters;
    final error = queryParameters["error"];
    final state = queryParameters["state"];
    if (error != null) {
      final errorDescription = queryParameters["error_description"];
      final errorURI = queryParameters["error_uri"];
      throw OAuthException(
        error: error,
        errorDescription: errorDescription,
        errorURI: errorURI,
        state: state,
      );
    }

    final code = queryParameters["code"];
    if (code == null) {
      throw OAuthException(
        error: "invalid_request",
        errorDescription: "code is missing",
      );
    }

    final tokenRequest = OIDCTokenRequest(
      grantType: "authorization_code",
      clientID: clientID,
      code: code,
      redirectURI: redirectURI,
      codeVerifier: codeVerifier.value,
      xDeviceInfo: xDeviceInfo,
    );
    final tokenResponse = await _apiClient.sendTokenRequest(tokenRequest);
    return tokenResponse;
  }

  Future<UserInfo> _finishAuthentication({
    required Uri url,
    required String redirectURI,
    required CodeVerifier codeVerifier,
    required String xDeviceInfo,
  }) async {
    final tokenResponse = await _exchangeCode(
      url: url,
      redirectURI: redirectURI,
      codeVerifier: codeVerifier,
      xDeviceInfo: xDeviceInfo,
    );
    await _persistTokenResponse(
        tokenResponse, SessionStateChangeReason.authenticated);
    await disableBiometric();
    final userInfo = await _apiClient.getUserInfo();
    return userInfo;
  }

  Future<UserInfo> _finishReauthentication({
    required Uri url,
    required String redirectURI,
    required CodeVerifier codeVerifier,
    required String xDeviceInfo,
  }) async {
    final tokenResponse = await _exchangeCode(
      url: url,
      redirectURI: redirectURI,
      codeVerifier: codeVerifier,
      xDeviceInfo: xDeviceInfo,
    );
    final idToken = tokenResponse.idToken;
    if (idToken != null) {
      _idToken = idToken;
    }
    final userInfo = await _apiClient.getUserInfo();
    return userInfo;
  }

  Future<void> _persistTokenResponse(
      OIDCTokenResponse tokenResponse, SessionStateChangeReason reason) async {
    final idToken = tokenResponse.idToken;
    if (idToken != null) {
      _idToken = idToken;
    }

    final accessToken = tokenResponse.accessToken!;
    _accessToken = accessToken;

    final refreshToken = tokenResponse.refreshToken;
    if (refreshToken != null) {
      _refreshToken = refreshToken;
      await _tokenStorage.setRefreshToken(name, refreshToken);
    }

    final expiresIn = tokenResponse.expiresIn!;
    _expireAt = DateTime.now()
        .toUtc()
        .add(Duration(seconds: (expiresIn * _expiresInPercentage).toInt()));

    _setSessionState(SessionState.authenticated, reason);
  }
}
