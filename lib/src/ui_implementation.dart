import 'native.dart' as native;

abstract class UIImplementation {
  Future<String> openAuthorizationURL(
      {required String url,
      required String redirectURI,
      required bool shareCookiesWithDeviceBrowser});
}

class DeviceBrowserUIImplementation implements UIImplementation {
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

class WebKitWebViewUIImplementationOptionsIOS {
  final ModalPresentationStyle? modalPresentationStyle;
  final int? backgroundColor;
  final int? navigationBarBackgroundColor;
  final int? navigationBarButtonTintColor;

  WebKitWebViewUIImplementationOptionsIOS({
    this.modalPresentationStyle,
    this.backgroundColor,
    this.navigationBarBackgroundColor,
    this.navigationBarButtonTintColor,
  });
}

class WebKitWebViewUIImplementationOptionsAndroid {
  final int? actionBarBackgroundColor;
  final int? actionBarButtonTintColor;

  WebKitWebViewUIImplementationOptionsAndroid({
    this.actionBarBackgroundColor,
    this.actionBarButtonTintColor,
  });
}

class WebKitWebViewUIImplementationOptions {
  final WebKitWebViewUIImplementationOptionsIOS? ios;
  final WebKitWebViewUIImplementationOptionsAndroid? android;

  WebKitWebViewUIImplementationOptions({
    this.ios,
    this.android,
  });
}

class WebKitWebViewUIImplementation implements UIImplementation {
  final WebKitWebViewUIImplementationOptions? options;

  WebKitWebViewUIImplementation({
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
      actionBarBackgroundColor:
          options?.android?.actionBarBackgroundColor?.toRadixString(16),
      actionBarButtonTintColor:
          options?.android?.actionBarButtonTintColor?.toRadixString(16),
    );
  }
}
