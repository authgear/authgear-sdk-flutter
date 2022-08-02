import 'dart:async' show StreamSubscription;
import 'dart:io';
import 'package:flutter/material.dart' hide ColorScheme;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;
import 'package:flutter_authgear/flutter_authgear.dart';

const redirectURI = "com.authgear.exampleapp.flutter://host/path";
var wechatRedirectURI = "";

const _nativeMethodChannel = MethodChannel("example");

ColorScheme colorSchemeFromContext(BuildContext context) {
  final brightness = MediaQuery.of(context).platformBrightness;
  switch (brightness) {
    case Brightness.light:
      return ColorScheme.light;
    case Brightness.dark:
      return ColorScheme.dark;
  }
}

void main() {
  if (Platform.isIOS) {
    wechatRedirectURI =
        "https://authgear-demo-flutter.pandawork.com/authgear/open_wechat_app";
  }
  if (Platform.isAndroid) {
    wechatRedirectURI =
        "com.authgear.exampleapp.flutter://host/open_wechat_app";
  }
  // debugPaintSizeEnabled = true;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

final ios = BiometricOptionsIOS(
  localizedReason: "Use biometric to sign in",
  constraint: BiometricAccessConstraintIOS.biometryCurrentSet,
);

final android = BiometricOptionsAndroid(
  title: "Sign in with biometric",
  subtitle: "Sign in securely with biometric",
  description: "Use your enrolled biometric to sign in",
  negativeButtonText: "Cancel",
  constraint: [BiometricAccessConstraintAndroid.biometricStrong],
  invalidatedByBiometricEnrollment: true,
);

String _showError(dynamic e) {
  if (e is BiometricPrivateKeyNotFoundException) {
    if (Platform.isIOS) {
      return "Your Touch ID or Face ID has changed. For security reason, you have to set up biometric authentication again.";
    }
    if (Platform.isAndroid) {
      return "Your biometric info has changed. For security reason, you have to set up biometric authentication again.";
    }
  }
  if (e is BiometricNoEnrollmentException) {
    if (Platform.isIOS) {
      return "You do not have Face ID or Touch ID set up yet. Please set it up first.";
    }
    if (Platform.isAndroid) {
      return "You have not set up biometric yet. Please set up your fingerprint or face.";
    }
  }
  if (e is BiometricNotSupportedOrPermissionDeniedException) {
    if (Platform.isIOS) {
      return "If the developer should performed checking, then it is likely that you have denied the permission of Face ID. Please enable it in Settings";
    }
    if (Platform.isAndroid) {
      return "Your device does not support biometric. The developer should have checked this and not letting you to see feature that requires biometric";
    }
  }
  if (e is BiometricNoPasscodeException) {
    if (Platform.isIOS) {
      return "You device does not have passcode set up. Please set up a passcode.";
    }
    if (Platform.isAndroid) {
      return "You device does not have credential set up. Please set up either a PIN, a pattern or a password.";
    }
  }
  if (e is BiometricLockoutException) {
    return "The biometric is locked out due to too many failed attempts. The developer should handle this error by using normal authentication as a fallback. So normally you should not see this error";
  }

  return "$e";
}

class TextFieldWithLabel extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;

  const TextFieldWithLabel({
    Key? key,
    required this.label,
    required this.hintText,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(label),
        ),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
          ),
        ),
      ],
    );
  }
}

class SwitchWithLabel extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SwitchWithLabel({
    Key? key,
    required this.label,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class RadioOption<T> {
  final String label;
  final T? value;

  RadioOption({required this.label, required this.value});
}

class RadioGroup<T> extends StatelessWidget {
  final String title;
  final T? groupValue;
  final List<RadioOption<T>> options;
  final ValueChanged<T?> onChanged;

  const RadioGroup({
    Key? key,
    required this.title,
    required this.groupValue,
    required this.options,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Text(title),
          ),
        ),
        for (var option in options)
          RadioListTile<T?>(
            value: option.value,
            groupValue: groupValue,
            onChanged: onChanged,
            title: Text(option.label),
          ),
      ],
    );
  }
}

class SessionStateButton extends StatelessWidget {
  final SessionState sessionState;
  final SessionState targetState;
  final void Function()? onPressed;
  final String label;

  const SessionStateButton({
    Key? key,
    required this.sessionState,
    required this.targetState,
    required this.onPressed,
    required this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: sessionState == targetState ? onPressed : null,
      child: Text(label),
    );
  }
}

class _MyAppState extends State<MyApp> {
  Authgear _authgear = Authgear(endpoint: "", clientID: "");
  late SharedPreferences _sharedPreferences;
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _clientIDController = TextEditingController();
  StreamSubscription<SessionStateChangeEvent>? _sub;
  bool _loading = false;
  bool _useTransientTokenStorage = false;
  bool _shareSessionWithSystemBrowser = false;
  bool _isBiometricEnabled = false;
  bool get _unconfigured {
    return _authgear.endpoint != _endpointController.text ||
        _authgear.clientID != _clientIDController.text;
  }

  UserInfo? _userInfo;
  bool get _isAnonymous {
    final userInfo = _userInfo;
    if (userInfo == null) {
      return false;
    }
    return userInfo.isAnonymous;
  }

  AuthenticationPage? _page;
  ColorScheme? _colorScheme;

  ColorScheme? _getColorScheme(BuildContext context) {
    if (_colorScheme != null) {
      return _colorScheme;
    }
    return colorSchemeFromContext(context);
  }

  @override
  void initState() {
    super.initState();
    _endpointController.addListener(() {
      setState(() {});
    });
    _clientIDController.addListener(() {
      setState(() {});
    });

    void init() async {
      _sharedPreferences = await SharedPreferences.getInstance();
      final endpoint = _sharedPreferences.getString("authgear.endpoint");
      final clientID = _sharedPreferences.getString("authgear.clientID");
      if (endpoint != null && clientID != null) {
        _endpointController.text = endpoint;
        _clientIDController.text = clientID;
      }
    }

    init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _endpointController.dispose();
    _clientIDController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Plugin example app'),
            ),
            body: ListView(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: TextFieldWithLabel(
                    label: "Endpoint",
                    hintText: "Enter Authegar endpoint",
                    controller: _endpointController,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: TextFieldWithLabel(
                    label: "Client ID",
                    hintText: "Enter client ID",
                    controller: _clientIDController,
                  ),
                ),
                RadioGroup<AuthenticationPage>(
                  title: "Intial Page",
                  groupValue: _page,
                  options: [
                    RadioOption(
                      label: "Unset",
                      value: null,
                    ),
                    RadioOption(
                      label: "login",
                      value: AuthenticationPage.login,
                    ),
                    RadioOption(
                      label: "signup",
                      value: AuthenticationPage.signup,
                    ),
                  ],
                  onChanged: (newPage) {
                    setState(() {
                      _page = newPage;
                    });
                  },
                ),
                RadioGroup<ColorScheme>(
                  title: "Color Scheme",
                  groupValue: _colorScheme,
                  options: [
                    RadioOption(
                      label: "Use System",
                      value: null,
                    ),
                    RadioOption(
                      label: ColorScheme.light.name,
                      value: ColorScheme.light,
                    ),
                    RadioOption(
                      label: ColorScheme.dark.name,
                      value: ColorScheme.dark,
                    ),
                  ],
                  onChanged: (newColorScheme) {
                    setState(() {
                      _colorScheme = newColorScheme;
                    });
                  },
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  child: SwitchWithLabel(
                    label: "Use TransientTokenStorage",
                    value: _useTransientTokenStorage,
                    onChanged: (newValue) {
                      setState(() {
                        _useTransientTokenStorage = newValue;
                      });
                    },
                  ),
                ),
                Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: SwitchWithLabel(
                      label: "Share Session With Device Browser",
                      value: _shareSessionWithSystemBrowser,
                      onChanged: (newValue) {
                        setState(() {
                          _shareSessionWithSystemBrowser = newValue;
                        });
                      },
                    )),
                TextButton(
                  onPressed: () {
                    _onPressConfigure();
                  },
                  child: const Text("Configure"),
                ),
                SessionStateButton(
                  sessionState: _authgear.sessionState,
                  targetState: SessionState.noSession,
                  label: "Authenticate",
                  onPressed: _unconfigured || _loading
                      ? null
                      : () {
                          _onPressAuthenticate(context);
                        },
                ),
                SessionStateButton(
                  sessionState: _authgear.sessionState,
                  targetState: SessionState.noSession,
                  label: "Authenticate Anonymously",
                  onPressed: _unconfigured || _loading
                      ? null
                      : () {
                          _onPressAuthenticateAnonymously(context);
                        },
                ),
                SessionStateButton(
                  sessionState: _authgear.sessionState,
                  targetState: SessionState.authenticated,
                  label: "Promote Anonymous User",
                  onPressed: _unconfigured || _loading || !_isAnonymous
                      ? null
                      : () {
                          _onPressPromoteAnonymousUser(context);
                        },
                ),
                SessionStateButton(
                  sessionState: _authgear.sessionState,
                  targetState: SessionState.noSession,
                  label: "Authenticate Biometric",
                  onPressed: _unconfigured || _loading || !_isBiometricEnabled
                      ? null
                      : () {
                          _onPressAuthenticateBiometric(context);
                        },
                ),
                SessionStateButton(
                  sessionState: _authgear.sessionState,
                  targetState: SessionState.authenticated,
                  label: "Reauthenticate (web-only)",
                  onPressed: _unconfigured || _loading
                      ? null
                      : () {
                          _onPressReauthenticateWeb(context);
                        },
                ),
                SessionStateButton(
                  sessionState: _authgear.sessionState,
                  targetState: SessionState.authenticated,
                  label: "Reauthenticate (biometric or web)",
                  onPressed: _unconfigured || _loading
                      ? null
                      : () {
                          _onPressReauthenticate(context);
                        },
                ),
                SessionStateButton(
                  sessionState: _authgear.sessionState,
                  targetState: SessionState.authenticated,
                  label: "Enable Biometric",
                  onPressed: _unconfigured ||
                          _loading ||
                          _isBiometricEnabled ||
                          _isAnonymous
                      ? null
                      : () {
                          _onPressEnableBiometric(context);
                        },
                ),
                SessionStateButton(
                  sessionState: _authgear.sessionState,
                  targetState: SessionState.authenticated,
                  label: "Disable Biometric",
                  onPressed: _unconfigured || _loading || !_isBiometricEnabled
                      ? null
                      : () {
                          _onPressDisableBiometric(context);
                        },
                ),
                SessionStateButton(
                  sessionState: _authgear.sessionState,
                  targetState: SessionState.authenticated,
                  label: "Get UserInfo",
                  onPressed: _unconfigured || _loading
                      ? null
                      : () {
                          _onPressGetUserInfo(context);
                        },
                ),
                SessionStateButton(
                  sessionState: _authgear.sessionState,
                  targetState: SessionState.authenticated,
                  label: "Open Settings",
                  onPressed: _unconfigured || _loading
                      ? null
                      : () {
                          _onPressOpenSettings(context);
                        },
                ),
                SessionStateButton(
                  sessionState: _authgear.sessionState,
                  targetState: SessionState.authenticated,
                  label: "Show auth_time",
                  onPressed: _unconfigured || _loading
                      ? null
                      : () {
                          _onPressShowAuthTime(context);
                        },
                ),
                SessionStateButton(
                  sessionState: _authgear.sessionState,
                  targetState: SessionState.authenticated,
                  label: "Logout",
                  onPressed: _unconfigured || _loading
                      ? null
                      : () {
                          _onPressLogout(context);
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _syncAuthgearState() async {
    final isBiometricEnabled = await _authgear.isBiometricEnabled();
    setState(() {
      _isBiometricEnabled = isBiometricEnabled;
    });
  }

  Future<void> _onPressAuthenticate(BuildContext context) async {
    try {
      setState(() {
        _loading = true;
      });
      final userInfo = await _authgear.authenticate(
        redirectURI: redirectURI,
        page: _page,
        colorScheme: _getColorScheme(context),
        wechatRedirectURI: wechatRedirectURI,
      );
      setState(() {
        _userInfo = userInfo;
      });
    } catch (e) {
      onError(context, e);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onPressAuthenticateAnonymously(BuildContext context) async {
    try {
      setState(() {
        _loading = true;
      });
      final userInfo = await _authgear.authenticateAnonymously();
      setState(() {
        _userInfo = userInfo;
      });
    } catch (e) {
      onError(context, e);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onPressPromoteAnonymousUser(BuildContext context) async {
    try {
      setState(() {
        _loading = true;
      });
      final userInfo = await _authgear.promoteAnonymousUser(
        redirectURI: redirectURI,
        colorScheme: _getColorScheme(context),
        wechatRedirectURI: wechatRedirectURI,
      );
      setState(() {
        _userInfo = userInfo;
      });
    } catch (e) {
      onError(context, e);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onPressAuthenticateBiometric(BuildContext context) async {
    try {
      setState(() {
        _loading = true;
      });
      final userInfo = await _authgear.authenticateBiometric(
        ios: ios,
        android: android,
      );
      setState(() {
        _userInfo = userInfo;
      });
    } catch (e) {
      onError(context, e);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onPressReauthenticateWeb(BuildContext context) async {
    try {
      setState(() {
        _loading = true;
      });
      await _authgear.refreshIDToken();
      if (!_authgear.canReauthenticate) {
        throw Exception("canReauthenticate returns false for the current user");
      }
      final userInfo = await _authgear.reauthenticate(
        redirectURI: redirectURI,
        wechatRedirectURI: wechatRedirectURI,
      );
      setState(() {
        _userInfo = userInfo;
      });
    } catch (e) {
      onError(context, e);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onPressReauthenticate(BuildContext context) async {
    try {
      setState(() {
        _loading = true;
      });
      await _authgear.refreshIDToken();
      if (!_authgear.canReauthenticate) {
        throw Exception("canReauthenticate returns false for the current user");
      }
      final userInfo = await _authgear.reauthenticate(
        redirectURI: redirectURI,
        colorScheme: _getColorScheme(context),
        wechatRedirectURI: wechatRedirectURI,
        biometricIOS: ios,
        biometricAndroid: android,
      );
      setState(() {
        _userInfo = userInfo;
      });
    } catch (e) {
      onError(context, e);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onPressGetUserInfo(BuildContext context) async {
    try {
      setState(() {
        _loading = true;
      });
      final userInfo = await _authgear.getUserInfo();
      setState(() {
        _userInfo = userInfo;
      });
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("User Info"),
            content: Text(
              "sub: ${userInfo.sub}\nisAnonymous: ${userInfo.isAnonymous}\nisVerified: ${userInfo.isVerified}",
            ),
            actions: [
              TextButton(
                child: const Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      onError(context, e);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onPressLogout(BuildContext context) async {
    try {
      setState(() {
        _loading = true;
      });
      await _authgear.logout();
      setState(() {
        _userInfo = null;
      });
    } catch (e) {
      onError(context, e);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onPressConfigure() async {
    final endpoint = _endpointController.text;
    final clientID = _clientIDController.text;

    final authgear = Authgear(
      endpoint: endpoint,
      clientID: clientID,
      shareSessionWithSystemBrowser: _shareSessionWithSystemBrowser,
      tokenStorage: _useTransientTokenStorage ? TransientTokenStorage() : null,
      sendWechatAuthRequest: _sendWechatAuthRequest,
    );
    _sub?.cancel();
    await authgear.configure();
    await _sharedPreferences.setString(
      "authgear.endpoint",
      endpoint,
    );
    await _sharedPreferences.setString(
      "authgear.clientID",
      clientID,
    );

    UserInfo? userInfo;
    if (authgear.sessionState == SessionState.authenticated) {
      userInfo = await authgear.getUserInfo();
    }

    setState(() {
      _authgear = authgear;
      _userInfo = userInfo;
      _sub = _authgear.onSessionStateChange.listen((e) {
        _syncAuthgearState();
      });
      _syncAuthgearState();
    });
  }

  Future<void> _onPressOpenSettings(BuildContext context) async {
    try {
      setState(() {
        _loading = true;
      });
      await _authgear.open(
        page: SettingsPage.settings,
        colorScheme: _getColorScheme(context),
        wechatRedirectURI: wechatRedirectURI,
      );
    } catch (e) {
      onError(context, e);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onPressShowAuthTime(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("auth_time"),
          content: Text("${_authgear.authTime}"),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _onPressEnableBiometric(BuildContext context) async {
    try {
      setState(() {
        _loading = true;
      });
      await _authgear.checkBiometricSupported(
        ios: ios,
        android: android,
      );
      await _authgear.enableBiometric(
        ios: ios,
        android: android,
      );
      await _syncAuthgearState();
    } catch (e) {
      onError(context, e);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onPressDisableBiometric(BuildContext context) async {
    try {
      setState(() {
        _loading = true;
      });
      await _authgear.disableBiometric();
      await _syncAuthgearState();
    } catch (e) {
      onError(context, e);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _sendWechatAuthRequest(String state) async {
    try {
      final code =
          await _nativeMethodChannel.invokeMethod("sendWechatAuthRequest", {
        "state": state,
      });
      await _authgear.wechatAuthCallback(state: state, code: code);
    } on PlatformException catch (e) {
      print("exception: $e");
    }
  }

  void onError(BuildContext context, dynamic e) {
    if (e is CancelException) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Error"),
          content: Text(_showError(e)),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
