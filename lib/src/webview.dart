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

enum ModalPresentationStyle {
  automatic,
  fullScreen,
  pageSheet,
}

extension ModalPresentationStyleExtension on ModalPresentationStyle {
  String get value {
    switch (this) {
      case ModalPresentationStyle.automatic:
        return "automatic";
      case ModalPresentationStyle.fullScreen:
        return "fullScreen";
      case ModalPresentationStyle.pageSheet:
        return "pageSheet";
    }
  }
}

class PlatformWebViewOptionsIOS {
  final ModalPresentationStyle? modalPresentationStyle;
  final int? backgroundColor;
  final int? navigationBarBackgroundColor;
  final int? navigationBarButtonTintColor;

  PlatformWebViewOptionsIOS({
    this.modalPresentationStyle,
    this.backgroundColor,
    this.navigationBarBackgroundColor,
    this.navigationBarButtonTintColor,
  });
}

class PlatformWebViewOptions {
  final PlatformWebViewOptionsIOS? ios;

  PlatformWebViewOptions({
    this.ios,
  });
}

class PlatformWebView implements WebView {
  final PlatformWebViewOptions? options;

  PlatformWebView({
    this.options,
  });

  @override
  Future<String> openAuthorizationURL({
    required String url,
    required String redirectURI,
    required bool shareCookiesWithDeviceBrowser,
  }) {
    return native.openAuthorizeURLWithWebView(
      url: url,
      redirectURI: redirectURI,
      modalPresentationStyle: options?.ios?.modalPresentationStyle?.value,
      backgroundColor: options?.ios?.backgroundColor?.toRadixString(16),
      navigationBarBackgroundColor:
          options?.ios?.navigationBarBackgroundColor?.toRadixString(16),
      navigationBarButtonTintColor:
          options?.ios?.navigationBarButtonTintColor?.toRadixString(16),
    );
  }
}
