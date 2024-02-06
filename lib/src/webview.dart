import 'native.dart' as native;

abstract class WebView {
  Future<String> openAuthorizationURL(
      {required String url,
      required String redirectURI,
      required bool shareCookiesWithDeviceBrowser});
}

class DefaultWebView implements WebView {
  @override
  Future<String> openAuthorizationURL({
    required String url,
    required String redirectURI,
    required bool shareCookiesWithDeviceBrowser,
  }) {
    final preferEphemeral = !shareCookiesWithDeviceBrowser;
    return native.openAuthorizeURL(
      url: url,
      redirectURI: redirectURI,
      preferEphemeral: preferEphemeral,
    );
  }
}
