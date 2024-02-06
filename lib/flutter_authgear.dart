/// Authgear Flutter SDK.
///
/// To get started, create an instance of [Authgear].
/// You should use a single instance throughout the app.
///
/// The session state could change at any given time,
/// subscribe to [Authgear.onSessionStateChange] to listen for any state change event.
///
/// Use [Authgear.authenticate] to authenticate the end user.
///
/// Use [Authgear.open] to open the settings page to let the end-user to manage their account settings.
///
/// Use [Authgear.wrapHttpClient] to make a [Client] capable of injecting access token into Authorization header.
library authgear;

import 'package:http/http.dart' show Client;

export 'src/type.dart'
    show
        SessionState,
        SessionStateChangeReason,
        PromptOption,
        ColorScheme,
        AuthenticationPage,
        SettingsPage,
        UserInfo,
        BiometricAccessConstraintAndroid,
        BiometricAccessConstraintIOS,
        BiometricOptionsAndroid,
        BiometricOptionsIOS,
        BiometricLAPolicy;
export 'src/storage.dart'
    show TokenStorage, TransientTokenStorage, PersistentTokenStorage;
export 'src/container.dart' show SessionStateChangeEvent, Authgear;
export 'src/experimental.dart' show AuthgearExperimental, AuthenticateRequest;
export 'src/exception.dart'
    show
        AuthgearException,
        CancelException,
        OAuthException,
        ServerException,
        BiometricPrivateKeyNotFoundException,
        BiometricNotSupportedOrPermissionDeniedException,
        BiometricNoPasscodeException,
        BiometricNoEnrollmentException,
        BiometricLockoutException;
export 'src/webview.dart'
    show
        WebView,
        DefaultWebView;
