import 'code_verifier.dart';
import 'container.dart';
import 'type.dart';

class AuthgearExperimental {
  Authgear authgear;

  AuthgearExperimental(this.authgear);

  Future<AuthenticateRequest> createAuthenticateRequest({
    required String redirectURI,
    String? state,
    List<PromptOption>? prompt,
    String? loginHint,
    List<String>? uiLocales,
    ColorScheme? colorScheme,
    String? wechatRedirectURI,
    AuthenticationPage? page,
  }) async {
    final options = AuthenticateOptions(
      redirectURI: redirectURI,
      isSsoEnabled: authgear.isSsoEnabled,
      state: state,
      prompt: prompt,
      loginHint: loginHint,
      uiLocales: uiLocales,
      colorScheme: colorScheme,
      wechatRedirectURI: wechatRedirectURI,
      page: page,
    );
    final request = await authgear.internalCreateAuthenticateRequest(options);
    return AuthenticateRequest.fromInternal(request);
  }
}

class AuthenticateRequest {
  final Uri url;
  final String redirectURI;
  final CodeVerifier _verifier;

  AuthenticateRequest({
    required this.url,
    required this.redirectURI,
    required CodeVerifier verifier,
  }) : _verifier = verifier;

  AuthenticateRequest.fromInternal(InternalAuthenticateRequest internalRequest)
      : url = internalRequest.url,
        redirectURI = internalRequest.redirectURI,
        _verifier = internalRequest.verifier;
}
