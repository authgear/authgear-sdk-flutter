import 'dart:io' show Platform;
import 'dart:convert' show utf8, jsonDecode, jsonEncode;
import 'package:http/http.dart'
    show Client, Response, BaseClient, BaseRequest, StreamedResponse;
import 'exception.dart';
import 'type.dart';

class OIDCAuthenticationRequest {
  final String clientID;
  final String redirectURI;
  final String responseType;
  final List<String> scope;
  final String? codeChallenge;
  final String? state;
  final List<PromptOption>? prompt;
  final String? loginHint;
  final List<String>? uiLocales;
  final String? idTokenHint;
  final int? maxAge;
  final AuthenticationPage? page;
  final bool? suppressIDPSessionCookie;

  OIDCAuthenticationRequest({
    required this.clientID,
    required this.redirectURI,
    required this.responseType,
    required this.scope,
    this.codeChallenge,
    this.state,
    this.prompt,
    this.loginHint,
    this.uiLocales,
    this.idTokenHint,
    this.maxAge,
    this.page,
    this.suppressIDPSessionCookie,
  });

  Map<String, String> toQueryParameters() {
    final q = {
      "response_type": responseType,
      "client_id": clientID,
      "redirect_uri": redirectURI,
      "scope": scope.join(" "),
    };

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

    final maxAge = this.maxAge;
    if (maxAge != null) {
      q["max_age"] = maxAge.toString();
    }

    final page = this.page;
    if (page != null) {
      q["x_page"] = page.name;
    }

    final suppressIDPSessionCookie = this.suppressIDPSessionCookie;
    if (suppressIDPSessionCookie != null && suppressIDPSessionCookie == true) {
      q["x_suppress_idp_session_cookie"] = "true";
    }

    return q;
  }
}

class OIDCTokenRequest {
  final String grantType;
  final String clientID;
  final String? code;
  final String? redirectURI;
  final String? codeVerifier;
  final String? refreshToken;
  final String? accessToken;
  final String? jwt;
  final String? xDeviceInfo;

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
  });

  Map<String, String> toQueryParameters() {
    final q = {
      "client_id": clientID,
      "grant_type": grantType,
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

    return q;
  }
}

class OIDCTokenResponse {
  final String? idToken;
  final String? tokenType;
  final String? accessToken;
  final int? expiresIn;
  final String? refreshToken;

  OIDCTokenResponse.fromJSON(dynamic json)
      : idToken = json["id_token"],
        tokenType = json["token_type"],
        accessToken = json["access_token"],
        expiresIn = json["expires_in"]?.toInt(),
        refreshToken = json["refresh_token"];
}

class APIClient {
  final String endpoint;
  final Client _plainHttpClient;
  final AuthgearHttpClient _authgearHttpClient;
  OIDCConfiguration? _config;

  APIClient({
    required this.endpoint,
    required Client plainHttpClient,
    required AuthgearHttpClient authgearHttpClient,
  })  : _plainHttpClient = plainHttpClient,
        _authgearHttpClient = authgearHttpClient;

  Future<OIDCConfiguration> fetchOIDCConfiguration() async {
    final config = _config;
    if (config != null) {
      return config;
    }

    final url =
        Uri.parse(endpoint).replace(path: "/.well-known/openid-configuration");
    final resp = await _plainHttpClient.get(url);
    final json = jsonDecode(utf8.decode(resp.bodyBytes));
    final newConfig = OIDCConfiguration.fromJSON(json);
    _config = newConfig;
    return newConfig;
  }

  Future<OIDCTokenResponse> sendTokenRequest(OIDCTokenRequest request,
      {bool includeAccessToken = false}) async {
    final config = await fetchOIDCConfiguration();
    final url = Uri.parse(config.tokenEndpoint);
    final clientToUse =
        includeAccessToken ? _authgearHttpClient : _plainHttpClient;
    final httpResponse =
        await clientToUse.post(url, body: request.toQueryParameters());
    return _decodeOIDCResponse(httpResponse, OIDCTokenResponse.fromJSON);
  }

  Future<UserInfo> getUserInfo() async {
    final config = await fetchOIDCConfiguration();
    final url = Uri.parse(config.userinfoEndpoint);
    final httpResponse = await _authgearHttpClient.get(url);
    return _decodeOIDCResponse(httpResponse, UserInfo.fromJSON);
  }

  Future<void> revoke(String refreshToken) async {
    final config = await fetchOIDCConfiguration();
    final url = Uri.parse(config.revocationEndpoint);
    final body = {
      "token": refreshToken,
    };
    await _plainHttpClient.post(url, body: body);
  }

  Future<AppSessionTokenResponse> getAppSessionToken(
      String refreshToken) async {
    final url = Uri.parse(endpoint).replace(path: "/oauth2/app_session_token");
    final httpResponse = await _plainHttpClient.post(url,
        headers: {
          "content-type": "application/json; charset=UTF-8",
        },
        body: jsonEncode({
          "refresh_token": refreshToken,
        }));
    return _decodeAPIResponse(httpResponse, AppSessionTokenResponse.fromJSON);
  }

  T _decodeOIDCResponse<T>(Response resp, T Function(dynamic) f) {
    final json = jsonDecode(utf8.decode(resp.bodyBytes));
    String? error = json["error"];
    if (error != null) {
      throw OAuthException(
        error: error,
        errorDescription: json["error_description"],
        errorURI: json["error_uri"],
        state: json["state"],
      );
    }
    return f(json);
  }

  T _decodeAPIResponse<T>(Response resp, T Function(dynamic) f) {
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
