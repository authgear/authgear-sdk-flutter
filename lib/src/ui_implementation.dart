import 'package:flutter/services.dart' show MethodChannel;
import 'dart:math' as math;
import 'native.dart' as native;

var _rng = math.Random.secure();

abstract class UIImplementation {
  Future<String> openAuthorizationURL({
    required String url,
    required String redirectURI,
    required bool shareCookiesWithDeviceBrowser,
  });
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

enum ModalPresentationStyle { automatic, fullScreen, pageSheet }

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
  final int? navigationBarBackgroundColor;
  final int? navigationBarButtonTintColor;
  final bool? isInspectable;
  final String? wechatRedirectURI;

  WebKitWebViewUIImplementationOptionsIOS({
    this.modalPresentationStyle,
    this.navigationBarBackgroundColor,
    this.navigationBarButtonTintColor,
    this.isInspectable,
    this.wechatRedirectURI,
  });
}

class WebKitWebViewUIImplementationOptionsAndroid {
  final int? actionBarBackgroundColor;
  final int? actionBarButtonTintColor;
  final String? wechatRedirectURI;

  WebKitWebViewUIImplementationOptionsAndroid({
    this.actionBarBackgroundColor,
    this.actionBarButtonTintColor,
    this.wechatRedirectURI,
  });
}

class WebKitWebViewUIImplementationOptions {
  final WebKitWebViewUIImplementationOptionsIOS? ios;
  final WebKitWebViewUIImplementationOptionsAndroid? android;
  final Future<void> Function(String)? sendWechatAuthRequest;

  WebKitWebViewUIImplementationOptions({
    this.ios,
    this.android,
    this.sendWechatAuthRequest,
  });
}

class WebKitWebViewUIImplementation implements UIImplementation {
  final WebKitWebViewUIImplementationOptions? options;

  WebKitWebViewUIImplementation({this.options});

  @override
  Future<String> openAuthorizationURL({
    required String url,
    required String redirectURI,
    required bool shareCookiesWithDeviceBrowser,
  }) async {
    final id = _rng.nextInt(math.pow(2, 32) as int).toRadixString(16);
    final methodChannelName = "flutter_authgear:wechat:$id";

    final methodChannel = MethodChannel(methodChannelName);
    methodChannel.setMethodCallHandler((call) async {
      final uri = Uri.parse(call.arguments);
      final state = uri.queryParameters["state"];
      if (state != null) {
        final sendWechatAuthRequest = options?.sendWechatAuthRequest;
        if (sendWechatAuthRequest != null) {
          sendWechatAuthRequest(state);
        }
      }
    });

    try {
      return await native.openAuthorizeURLWithWebView(
        methodChannelName: methodChannelName,
        url: url,
        redirectURI: redirectURI,
        modalPresentationStyle: options?.ios?.modalPresentationStyle?.value,
        navigationBarBackgroundColor:
            options?.ios?.navigationBarBackgroundColor?.toRadixString(16),
        navigationBarButtonTintColor:
            options?.ios?.navigationBarButtonTintColor?.toRadixString(16),
        iosIsInspectable: options?.ios?.isInspectable,
        actionBarBackgroundColor:
            options?.android?.actionBarBackgroundColor?.toRadixString(16),
        actionBarButtonTintColor:
            options?.android?.actionBarButtonTintColor?.toRadixString(16),
        iosWechatRedirectURI: options?.ios?.wechatRedirectURI,
        androidWechatRedirectURI: options?.android?.wechatRedirectURI,
      );
    } finally {
      // Clean up the listener.
      methodChannel.setMethodCallHandler(null);
    }
  }
}
