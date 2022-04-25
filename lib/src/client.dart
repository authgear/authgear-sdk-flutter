import 'dart:io' show Platform;
import 'dart:convert' show utf8, jsonDecode;
import 'package:http/http.dart' show Client, Response;
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
  final String? jwt;
  final String? xDeviceInfo;

  OIDCTokenRequest({
    required this.grantType,
    required this.clientID,
    this.code,
    this.redirectURI,
    this.codeVerifier,
    this.refreshToken,
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
  final Client _client;
  OIDCConfiguration? _config;

  APIClient({required this.endpoint}) : _client = Client();

  Future<OIDCConfiguration> fetchOIDCConfiguration() async {
    final config = _config;
    if (config != null) {
      return config;
    }

    final url =
        Uri.parse(endpoint).replace(path: "/.well-known/openid-configuration");
    final resp = await _client.get(url);
    final json = jsonDecode(utf8.decode(resp.bodyBytes));
    final newConfig = OIDCConfiguration.fromJSON(json);
    _config = newConfig;
    return newConfig;
  }

  Future<OIDCTokenResponse> sendTokenRequest(OIDCTokenRequest request) async {
    final config = await fetchOIDCConfiguration();
    final url = Uri.parse(config.tokenEndpoint);
    final httpResponse =
        await _client.post(url, body: request.toQueryParameters());
    return _decodeOIDCResponse(httpResponse, OIDCTokenResponse.fromJSON);
  }

  Future<UserInfo> getUserInfo(String accessToken) async {
    final config = await fetchOIDCConfiguration();
    final url = Uri.parse(config.userinfoEndpoint);
    final headers = {
      "authorization": "Bearer $accessToken",
    };
    final httpResponse = await _client.get(url, headers: headers);
    return _decodeOIDCResponse(httpResponse, UserInfo.fromJSON);
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
}
