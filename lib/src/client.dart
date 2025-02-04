import 'dart:io' show Platform;
import 'dart:convert' show utf8, jsonDecode, jsonEncode;
import 'package:flutter_authgear/src/dpop.dart';
import 'package:http/http.dart'
    show Client, Response, BaseClient, BaseRequest, StreamedResponse;
import 'exception.dart';
import 'type.dart';

class OIDCAuthenticationRequest {
  final String clientID;
  final String redirectURI;
  final ResponseType responseType;
  final bool? isSsoEnabled;
  final List<String>? scope;
  final String? codeChallenge;
  final String? state;
  final List<PromptOption>? prompt;
  final String? loginHint;
  final List<String>? uiLocales;
  final ColorScheme? colorScheme;
  final String? idTokenHint;
  final int? maxAge;
  final AuthenticationPage? page;
  final String? wechatRedirectURI;
  final String? oauthProviderAlias;
  final SettingsAction? settingsAction;
  final String? settingsActionQuery;
  final String? authenticationFlowGroup;
  final ResponseMode? responseMode;
  final String? xPreAuthenticatedURLToken;
  final String? dpopJKT;

  OIDCAuthenticationRequest({
    required this.clientID,
    required this.redirectURI,
    required this.responseType,
    this.isSsoEnabled,
    this.scope,
    this.codeChallenge,
    this.state,
    this.prompt,
    this.loginHint,
    this.uiLocales,
    this.colorScheme,
    this.idTokenHint,
    this.maxAge,
    this.page,
    this.wechatRedirectURI,
    this.oauthProviderAlias,
    this.settingsAction,
    this.settingsActionQuery,
    this.authenticationFlowGroup,
    this.responseMode,
    this.xPreAuthenticatedURLToken,
    this.dpopJKT,
  });

  Map<String, String> toQueryParameters() {
    final q = {
      "response_type": responseType.value,
      "client_id": clientID,
      "redirect_uri": redirectURI,
    };

    final scope = this.scope;
    if (scope != null) {
      q["scope"] = scope.join(" ");
    }

    if (Platform.isIOS) {
      q["x_platform"] = "ios";
    }
    if (Platform.isAndroid) {
      q["x_platform"] = "android";
    }

    final codeChallenge = this.codeChallenge;
    if (codeChallenge != null) {
      q["code_challenge_method"] = "S256";
      q["code_challenge"] = codeChallenge;
    }

    final state = this.state;
    if (state != null) {
      q["state"] = state;
    }

    final prompt = this.prompt?.map((p) => p.value).join(" ") ?? "";
    if (prompt != "") {
      q["prompt"] = prompt;
    }

    final loginHint = this.loginHint;
    if (loginHint != null) {
      q["login_hint"] = loginHint;
    }

    final idTokenHint = this.idTokenHint;
    if (idTokenHint != null) {
      q["id_token_hint"] = idTokenHint;
    }

    final uiLocales = this.uiLocales?.join(" ") ?? "";
    if (uiLocales != "") {
      q["ui_locales"] = uiLocales;
    }

    final colorScheme = this.colorScheme;
    if (colorScheme != null) {
      q["x_color_scheme"] = colorScheme.name;
    }

    final maxAge = this.maxAge;
    if (maxAge != null) {
      q["max_age"] = maxAge.toString();
    }

    final page = this.page;
    if (page != null) {
      q["x_page"] = page.name;
    }

    final isSsoEnabled = this.isSsoEnabled;
    if (isSsoEnabled == false) {
      // For backward compatibility
      // If the developer updates the SDK but not the server
      q["x_suppress_idp_session_cookie"] = "true";
    }

    if (isSsoEnabled != null) {
      q["x_sso_enabled"] = isSsoEnabled ? "true" : "false";
    }

    final oauthProviderAlias = this.oauthProviderAlias;
    if (oauthProviderAlias != null) {
      q["x_oauth_provider_alias"] = oauthProviderAlias;
    }

    final wechatRedirectURI = this.wechatRedirectURI;
    if (wechatRedirectURI != null) {
      q["x_wechat_redirect_uri"] = wechatRedirectURI;
    }

    final settingsAction = this.settingsAction;
    if (settingsAction != null) {
      q["x_settings_action"] = settingsAction.value;
    }

    final settingsActionQuery = this.settingsActionQuery;
    if (settingsActionQuery != null) {
      q["x_settings_action_query"] = settingsActionQuery;
    }

    final authenticationFlowGroup = this.authenticationFlowGroup;
    if (authenticationFlowGroup != null) {
      q["x_authentication_flow_group"] = authenticationFlowGroup;
    }

    final responseMode = this.responseMode;
    if (responseMode != null) {
      q["response_mode"] = responseMode.value;
    }

    final xPreAuthenticatedURLToken = this.xPreAuthenticatedURLToken;
    if (xPreAuthenticatedURLToken != null) {
      q["x_pre_authenticated_url_token"] = xPreAuthenticatedURLToken;
    }

    final dpopJKT = this.dpopJKT;
    if (dpopJKT != null) {
      q["dpop_jkt"] = dpopJKT;
    }

    return q;
  }
}

class OIDCTokenRequest {
  final GrantType grantType;
  final String clientID;
  final String? code;
  final String? redirectURI;
  final String? codeVerifier;
  final String? refreshToken;
  final String? accessToken;
  final String? jwt;
  final String? xDeviceInfo;
  final String? deviceSecret;
  final RequestedTokenType? requestedTokenType;
  final String? audience;
  final SubjectTokenType? subjectTokenType;
  final String? subjectToken;
  final ActorTokenType? actorTokenType;
  final String? actorToken;

  OIDCTokenRequest({
    required this.grantType,
    required this.clientID,
    this.code,
    this.redirectURI,
    this.codeVerifier,
    this.refreshToken,
    this.accessToken,
    this.jwt,
    this.xDeviceInfo,
    this.deviceSecret,
    this.requestedTokenType,
    this.audience,
    this.subjectTokenType,
    this.subjectToken,
    this.actorTokenType,
    this.actorToken,
  });

  Map<String, String> toQueryParameters() {
    final q = {
      "client_id": clientID,
      "grant_type": grantType.value,
    };

    final code = this.code;
    if (code != null) {
      q["code"] = code;
    }

    final redirectURI = this.redirectURI;
    if (redirectURI != null) {
      q["redirect_uri"] = redirectURI;
    }

    final codeVerifier = this.codeVerifier;
    if (codeVerifier != null) {
      q["code_verifier"] = codeVerifier;
    }

    final refreshToken = this.refreshToken;
    if (refreshToken != null) {
      q["refresh_token"] = refreshToken;
    }

    final accessToken = this.accessToken;
    if (accessToken != null) {
      q["access_token"] = accessToken;
    }

    final jwt = this.jwt;
    if (jwt != null) {
      q["jwt"] = jwt;
    }

    final xDeviceInfo = this.xDeviceInfo;
    if (xDeviceInfo != null) {
      q["x_device_info"] = xDeviceInfo;
    }

    final deviceSecret = this.deviceSecret;
    if (deviceSecret != null) {
      q["device_secret"] = deviceSecret;
    }

    final requestedTokenType = this.requestedTokenType;
    if (requestedTokenType != null) {
      q["requested_token_type"] = requestedTokenType.value;
    }

    final audience = this.audience;
    if (audience != null) {
      q["audience"] = audience;
    }

    final subjectTokenType = this.subjectTokenType;
    if (subjectTokenType != null) {
      q["subject_token_type"] = subjectTokenType.value;
    }
    final subjectToken = this.subjectToken;
    if (subjectToken != null) {
      q["subject_token"] = subjectToken;
    }

    final actorTokenType = this.actorTokenType;
    if (actorTokenType != null) {
      q["actor_token_type"] = actorTokenType.value;
    }
    final actorToken = this.actorToken;
    if (actorToken != null) {
      q["actor_token"] = actorToken;
    }

    return q;
  }
}

class OIDCTokenResponse {
  final String? idToken;
  final String? tokenType;
  final String? accessToken;
  final int? expiresIn;
  final String? refreshToken;
  final String? deviceSecret;

  OIDCTokenResponse.fromJSON(dynamic json)
      : idToken = json["id_token"],
        tokenType = json["token_type"],
        accessToken = json["access_token"],
        expiresIn = json["expires_in"]?.toInt(),
        refreshToken = json["refresh_token"],
        deviceSecret = json["device_secret"];
}

class BiometricRequest {
  final String clientID;
  final String jwt;
  final List<String>? scope;

  BiometricRequest({required this.clientID, required this.jwt, this.scope});

  Map<String, String> toQueryParameters() {
    Map<String, String> q = {
      "grant_type": "urn:authgear:params:oauth:grant-type:biometric-request",
      "client_id": clientID,
      "jwt": jwt,
    };
    final scope = this.scope;
    if (scope != null) {
      q["scope"] = scope.join(" ");
    }
    return q;
  }
}

class AnonymousRequest {
  final String clientID;
  final String jwt;

  AnonymousRequest({required this.clientID, required this.jwt});

  Map<String, String> toQueryParameters() {
    return {
      "grant_type": "urn:authgear:params:oauth:grant-type:anonymous-request",
      "client_id": clientID,
      "jwt": jwt,
    };
  }
}

class APIClient {
  final String endpoint;
  final Client _plainHttpClient;
  final AuthgearHttpClient _authgearHttpClient;
  final DPoPProvider _dpopProvider;
  OIDCConfiguration? _config;

  APIClient({
    required this.endpoint,
    required Client plainHttpClient,
    required AuthgearHttpClient authgearHttpClient,
    required DPoPProvider dpopProvider,
  })  : _plainHttpClient = plainHttpClient,
        _authgearHttpClient = authgearHttpClient,
        _dpopProvider = dpopProvider;

  Future<OIDCConfiguration> fetchOIDCConfiguration() async {
    final config = _config;
    if (config != null) {
      return config;
    }

    final url =
        Uri.parse(endpoint).replace(path: "/.well-known/openid-configuration");
    final resp = await _get(_plainHttpClient, url);
    final json = jsonDecode(utf8.decode(resp.bodyBytes));
    final newConfig = OIDCConfiguration.fromJSON(json);
    _config = newConfig;
    return newConfig;
  }

  Future<Uri> _buildApiUrl(String path) async {
    final config = await fetchOIDCConfiguration();
    final endpoint = Uri.parse(config.authorizationEndpoint);
    final origin = Uri.parse(endpoint.origin);
    return origin.replace(path: path);
  }

  Future<String> getApiOrigin() async {
    final config = await fetchOIDCConfiguration();
    final endpoint = Uri.parse(config.authorizationEndpoint);
    return endpoint.origin;
  }

  Future<OIDCTokenResponse> sendTokenRequest(OIDCTokenRequest request,
      {bool includeAccessToken = false}) async {
    final config = await fetchOIDCConfiguration();
    final url = Uri.parse(config.tokenEndpoint);
    final clientToUse =
        includeAccessToken ? _authgearHttpClient : _plainHttpClient;
    final httpResponse =
        await _post(clientToUse, url, body: request.toQueryParameters());
    return _decodeOIDCResponseJSON(httpResponse, OIDCTokenResponse.fromJSON);
  }

  Future<UserInfo> getUserInfo() async {
    final config = await fetchOIDCConfiguration();
    final url = Uri.parse(config.userinfoEndpoint);
    final httpResponse = await _get(_authgearHttpClient, url);
    return _decodeOIDCResponseJSON(httpResponse, UserInfo.fromJSON);
  }

  Future<void> revoke(String refreshToken) async {
    final config = await fetchOIDCConfiguration();
    final url = Uri.parse(config.revocationEndpoint);
    final body = {
      "token": refreshToken,
    };
    final httpResponse = await _post(_plainHttpClient, url, body: body);
    return _decodeOIDCResponse(httpResponse);
  }

  Future<AppSessionTokenResponse> getAppSessionToken(
      String refreshToken) async {
    final url = await _buildApiUrl("/oauth2/app_session_token");
    final httpResponse = await _post(_plainHttpClient, url,
        headers: {
          "content-type": "application/json; charset=UTF-8",
        },
        body: jsonEncode({
          "refresh_token": refreshToken,
        }));
    return _decodeAPIResponseJSON(
        httpResponse, AppSessionTokenResponse.fromJSON);
  }

  Future<void> sendSetupBiometricRequest(BiometricRequest request) async {
    final config = await fetchOIDCConfiguration();
    final url = Uri.parse(config.tokenEndpoint);
    final httpResponse = await _post(_authgearHttpClient, url,
        body: request.toQueryParameters());
    return _decodeOIDCResponse(httpResponse);
  }

  Future<OIDCTokenResponse> sendAuthenticateBiometricRequest(
      BiometricRequest request) async {
    final config = await fetchOIDCConfiguration();
    final url = Uri.parse(config.tokenEndpoint);
    final httpResponse = await _post(_authgearHttpClient, url,
        body: request.toQueryParameters());
    return _decodeOIDCResponseJSON(httpResponse, OIDCTokenResponse.fromJSON);
  }

  Future<OIDCTokenResponse> sendAuthenticateAnonymousRequest(
      AnonymousRequest request) async {
    final config = await fetchOIDCConfiguration();
    final url = Uri.parse(config.tokenEndpoint);
    final httpResponse =
        await _post(_plainHttpClient, url, body: request.toQueryParameters());
    return _decodeOIDCResponseJSON(httpResponse, OIDCTokenResponse.fromJSON);
  }

  Future<ChallengeResponse> getChallenge(String purpose) async {
    final url = await _buildApiUrl("/oauth2/challenge");
    final httpResponse = await _post(
      _plainHttpClient,
      url,
      headers: {
        "content-type": "application/json; charset=UTF-8",
      },
      body: jsonEncode({
        "purpose": purpose,
      }),
    );
    return _decodeAPIResponseJSON(httpResponse, ChallengeResponse.fromJSON);
  }

  Future<void> sendWechatAuthCallback({
    required String state,
    required String code,
  }) async {
    final url = await _buildApiUrl("/sso/wechat/callback");
    final httpResponse = await _post(
      _plainHttpClient,
      url,
      body: {
        "state": state,
        "code": code,
      },
    );
    return _decodeAPIResponse(httpResponse);
  }

  Future<Map<String, String>> _composeRequestHeaders(
      Uri url, String method, Map<String, String> headers) async {
    final dpopProof =
        await _dpopProvider.generateDPoPProof(htm: method, htu: url.toString());
    Map<String, String> h = Map.from(headers);
    if (dpopProof != null) {
      h["DPoP"] = dpopProof;
    }
    return h;
  }

  Future<Response> _post(Client client, Uri url,
      {Map<String, String>? headers, Object? body}) async {
    final h = await _composeRequestHeaders(url, "POST", headers ?? {});
    return await client.post(url, headers: h, body: body);
  }

  Future<Response> _get(Client client, Uri url,
      {Map<String, String>? headers}) async {
    final h = await _composeRequestHeaders(url, "GET", headers ?? {});
    return await client.get(url, headers: h);
  }

  void _decodeOIDCResponse(Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 400) {
      final json = jsonDecode(utf8.decode(resp.bodyBytes));
      String error = json["error"];
      throw OAuthException(
        error: error,
        errorDescription: json["error_description"],
        errorURI: json["error_uri"],
        state: json["state"],
      );
    }
  }

  T _decodeOIDCResponseJSON<T>(Response resp, T Function(dynamic) f) {
    _decodeOIDCResponse(resp);
    final json = jsonDecode(utf8.decode(resp.bodyBytes));
    return f(json);
  }

  void _decodeAPIResponse(Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 400) {
      final json = jsonDecode(utf8.decode(resp.bodyBytes));
      dynamic error = json["error"];
      throw decodeException(error);
    }
  }

  T _decodeAPIResponseJSON<T>(Response resp, T Function(dynamic) f) {
    final json = jsonDecode(utf8.decode(resp.bodyBytes));
    dynamic error = json["error"];
    dynamic result = json["result"];
    if (result != null) {
      return f(result);
    }
    throw decodeException(error);
  }
}

class AuthgearHttpClient extends BaseClient {
  final AuthgearHttpClientDelegate _delegate;
  final Client _inner;

  AuthgearHttpClient(this._delegate, this._inner);

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final delegate = _delegate;
    final shouldRefresh = delegate.shouldRefreshAccessToken;
    if (shouldRefresh) {
      await delegate.refreshAccessToken();
    }
    final accessToken = delegate.accessToken;
    if (accessToken != null) {
      request.headers["authorization"] = "Bearer $accessToken";
    }
    final resp = await _inner.send(request);
    return resp;
  }
}
