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
import 'experimental.dart';
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

class InternalAuthenticateRequest {
  final Uri url;
  final String redirectURI;
  final CodeVerifier verifier;

  InternalAuthenticateRequest(
      {required this.url, required this.redirectURI, required this.verifier});
}

class AuthenticateOptions {
  final String redirectURI;
  final bool isSsoEnabled;
  final String? state;
  final List<PromptOption>? prompt;
  final String? loginHint;
  final List<String>? uiLocales;
  final ColorScheme? colorScheme;
  final String? wechatRedirectURI;
  final AuthenticationPage? page;

  AuthenticateOptions({
    required this.redirectURI,
    required this.isSsoEnabled,
    this.state,
    this.prompt,
    this.loginHint,
    this.uiLocales,
    this.colorScheme,
    this.wechatRedirectURI,
    this.page,
  });

  OIDCAuthenticationRequest toRequest(String clientID, CodeVerifier verifier) {
    return OIDCAuthenticationRequest(
      clientID: clientID,
      redirectURI: redirectURI,
      responseType: "code",
      scope: [
        "openid",
        "offline_access",
        "https://authgear.com/scopes/full-access",
      ],
      isSsoEnabled: isSsoEnabled,
      codeChallenge: verifier.codeChallenge,
      prompt: prompt,
      uiLocales: uiLocales,
      colorScheme: colorScheme,
      page: page,
      state: state,
      loginHint: loginHint,
      wechatRedirectURI: wechatRedirectURI,
    );
  }
}

// It seems that dart's convention of iOS' delegate is individual property of write-only function
// See https://api.dart.dev/stable/2.16.2/dart-io/HttpClient/authenticate.html
class Authgear implements AuthgearHttpClientDelegate {
  final String clientID;
  final String endpoint;
  final String name;
  final bool isSsoEnabled;
  final Future<void> Function(String)? sendWechatAuthRequest;

  final TokenStorage _tokenStorage;
  final ContainerStorage _storage;
  late final APIClient _apiClient;
  late final AuthgearExperimental experimental;

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
    this.isSsoEnabled = false,
    this.sendWechatAuthRequest,
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
    experimental = AuthgearExperimental(this);
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

  Future<Uri> internalBuildAuthorizationURL(
      OIDCAuthenticationRequest oidcRequest) async {
    final config = await _apiClient.fetchOIDCConfiguration();
    final authenticationURL = Uri.parse(config.authorizationEndpoint)
        .replace(queryParameters: oidcRequest.toQueryParameters());
    return authenticationURL;
  }

  Future<InternalAuthenticateRequest> internalCreateAuthenticateRequest(
      AuthenticateOptions options) async {
    final codeVerifier = CodeVerifier(_rng);
    final oidcRequest = options.toRequest(clientID, codeVerifier);
    final url = await internalBuildAuthorizationURL(oidcRequest);

    return InternalAuthenticateRequest(
      url: url,
      redirectURI: oidcRequest.redirectURI,
      verifier: codeVerifier,
    );
  }

  Future<UserInfo> authenticate({
    required String redirectURI,
    List<PromptOption>? prompt,
    List<String>? uiLocales,
    ColorScheme? colorScheme,
    AuthenticationPage? page,
    String? state,
    String? wechatRedirectURI,
  }) async {
    final authRequest =
        await internalCreateAuthenticateRequest(AuthenticateOptions(
      redirectURI: redirectURI,
      isSsoEnabled: isSsoEnabled,
      state: state,
      prompt: prompt,
      uiLocales: uiLocales,
      colorScheme: colorScheme,
      wechatRedirectURI: wechatRedirectURI,
      page: page,
    ));
    final resultURL = await native.authenticate(
      url: authRequest.url.toString(),
      redirectURI: authRequest.redirectURI,
      preferEphemeral: !isSsoEnabled,
      wechatRedirectURI: wechatRedirectURI,
      onWechatRedirectURI: _onWechatRedirectURI,
    );
    return await internalFinishAuthentication(
        url: Uri.parse(resultURL),
        redirectURI: redirectURI,
        codeVerifier: authRequest.verifier);
  }

  Future<UserInfo> reauthenticate({
    required String redirectURI,
    int maxAge = 0,
    List<String>? uiLocales,
    ColorScheme? colorScheme,
    String? wechatRedirectURI,
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
      isSsoEnabled: isSsoEnabled,
      codeChallenge: codeVerifier.codeChallenge,
      uiLocales: uiLocales,
      colorScheme: colorScheme,
      idTokenHint: idTokenHint,
      maxAge: maxAge,
      wechatRedirectURI: wechatRedirectURI,
    );
    final config = await _apiClient.fetchOIDCConfiguration();
    final authenticationURL = Uri.parse(config.authorizationEndpoint)
        .replace(queryParameters: oidcRequest.toQueryParameters());
    final resultURL = await native.authenticate(
      url: authenticationURL.toString(),
      redirectURI: redirectURI,
      preferEphemeral: !isSsoEnabled,
      wechatRedirectURI: wechatRedirectURI,
      onWechatRedirectURI: _onWechatRedirectURI,
    );
    final xDeviceInfo = await _getXDeviceInfo();
    return await _finishReauthentication(
        url: Uri.parse(resultURL),
        redirectURI: redirectURI,
        codeVerifier: codeVerifier,
        xDeviceInfo: xDeviceInfo);
  }

  Future<UserInfo> getUserInfo() async {
    return _getUserInfo();
  }

  Future<Uri> internalGenerateURL({
    required String redirectURI,
    List<String>? uiLocales,
    ColorScheme? colorScheme,
    String? wechatRedirectURI,
  }) async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) {
      throw Exception("authenticated user required");
    }
    final appSessionTokenResp = await _getAppSessionToken(refreshToken);
    final loginHint =
        Uri.parse("https://authgear.com/login_hint").replace(queryParameters: {
      "type": "app_session_token",
      "app_session_token": appSessionTokenResp.appSessionToken,
    }).toString();

    final oidcRequest = OIDCAuthenticationRequest(
      clientID: clientID,
      redirectURI: redirectURI,
      responseType: "none",
      scope: [
        "openid",
        "offline_access",
        "https://authgear.com/scopes/full-access",
      ],
      isSsoEnabled: isSsoEnabled,
      prompt: [PromptOption.none],
      loginHint: loginHint,
      uiLocales: uiLocales,
      colorScheme: colorScheme,
      wechatRedirectURI: wechatRedirectURI,
    );
    final config = await _apiClient.fetchOIDCConfiguration();
    return Uri.parse(config.authorizationEndpoint)
        .replace(queryParameters: oidcRequest.toQueryParameters());
  }

  Future<void> openURL({
    required String url,
    String? wechatRedirectURI,
  }) async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) {
      throw Exception("openURL requires authenticated user");
    }

    final targetURL = await internalGenerateURL(
      redirectURI: url,
      wechatRedirectURI: wechatRedirectURI,
    );
    await native.openURL(
      url: targetURL.toString(),
      wechatRedirectURI: wechatRedirectURI,
      onWechatRedirectURI: _onWechatRedirectURI,
    );
  }

  Future<void> _openAuthgearURL({
    required String path,
    List<String>? uiLocales,
    ColorScheme? colorScheme,
    String? wechatRedirectURI,
  }) async {
    final oidcConfig = await _apiClient.fetchOIDCConfiguration();
    final endpoint = Uri.parse(oidcConfig.authorizationEndpoint);
    final origin = Uri.parse(endpoint.origin);

    final Map<String, String> q = {};
    final uiLocalesString = uiLocales?.join(" ") ?? "";
    if (uiLocalesString != "") {
      q["ui_locales"] = uiLocalesString;
    }
    if (colorScheme != null) {
      q["x_color_scheme"] = colorScheme.name;
    }

    final url = origin.replace(path: path, queryParameters: q).toString();
    return openURL(url: url, wechatRedirectURI: wechatRedirectURI);
  }

  Future<void> open({
    required SettingsPage page,
    List<String>? uiLocales,
    ColorScheme? colorScheme,
    String? wechatRedirectURI,
  }) async {
    return _openAuthgearURL(
        path: page.path,
        uiLocales: uiLocales,
        colorScheme: colorScheme,
        wechatRedirectURI: wechatRedirectURI);
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

    try {
      final tokenResponse = await _apiClient.sendTokenRequest(tokenRequest,
          includeAccessToken: true);
      final idToken = tokenResponse.idToken;
      if (idToken != null) {
        _idToken = idToken;
      }
    } catch (e) {
      _handleInvalidGrantException(e);
      rethrow;
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
    } catch (e) {
      await _handleInvalidGrantException(e);
      if (e is OAuthException && e.error == "invalid_grant") {
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
    await _sendSetupBiometricRequest(BiometricRequest(
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
    String? wechatRedirectURI,
    List<String>? uiLocales,
    ColorScheme? colorScheme,
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
      isSsoEnabled: isSsoEnabled,
      codeChallenge: codeVerifier.codeChallenge,
      prompt: [PromptOption.login],
      loginHint: loginHint,
      uiLocales: uiLocales,
      colorScheme: colorScheme,
      wechatRedirectURI: wechatRedirectURI,
    );
    final config = await _apiClient.fetchOIDCConfiguration();
    final authenticationURL = Uri.parse(config.authorizationEndpoint)
        .replace(queryParameters: oidcRequest.toQueryParameters());
    final resultURL = await native.authenticate(
      url: authenticationURL.toString(),
      redirectURI: redirectURI,
      wechatRedirectURI: wechatRedirectURI,
      onWechatRedirectURI: _onWechatRedirectURI,
      preferEphemeral: !isSsoEnabled,
    );
    final userInfo = await internalFinishAuthentication(
        url: Uri.parse(resultURL),
        redirectURI: redirectURI,
        codeVerifier: codeVerifier);
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

  Future<void> wechatAuthCallback({
    required String state,
    required String code,
  }) async {
    await _apiClient.sendWechatAuthCallback(
      state: state,
      code: code,
    );
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

  Future<UserInfo> internalFinishAuthentication({
    required Uri url,
    required String redirectURI,
    required CodeVerifier codeVerifier,
  }) async {
    final xDeviceInfo = await _getXDeviceInfo();
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

  Future<void> _handleInvalidGrantException(dynamic e) async {
    bool clearSession = false;
    if (e is OAuthException) {
      if (e.error == "invalid_grant") {
        clearSession = true;
      }
    } else if (e is ServerException) {
      if (e.reason == "InvalidGrant") {
        clearSession = true;
      }
    }
    if (clearSession) {
      await _clearSession(SessionStateChangeReason.invalid);
    }
  }

  Future<AppSessionTokenResponse> _getAppSessionToken(
      String refreshToken) async {
    try {
      return await _apiClient.getAppSessionToken(refreshToken);
    } catch (e) {
      await _handleInvalidGrantException(e);
      rethrow;
    }
  }

  Future<UserInfo> _getUserInfo() async {
    try {
      return await _apiClient.getUserInfo();
    } catch (e) {
      await _handleInvalidGrantException(e);
      rethrow;
    }
  }

  Future<void> _sendSetupBiometricRequest(BiometricRequest request) async {
    try {
      return await _apiClient.sendSetupBiometricRequest(request);
    } catch (e) {
      await _handleInvalidGrantException(e);
      rethrow;
    }
  }

  void _onWechatRedirectURI(Uri uri) {
    final q = uri.queryParameters;
    final state = q["state"];
    if (state != null) {
      sendWechatAuthRequest?.call(state);
    }
  }
}
