import 'dart:async' show StreamSubscription;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;
import 'package:flutter_authgear/authgear.dart';

void main() {
  // debugPaintSizeEnabled = true;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

const redirectURI = "com.authgear.exampleapp.flutter://host/path";

String _showError(dynamic e) {
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
  bool get _unconfigured {
    return _authgear.endpoint != _endpointController.text ||
        _authgear.clientID != _clientIDController.text;
  }

  AuthenticationPage? _page;

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

  Future<void> _onPressAuthenticate(BuildContext context) async {
    try {
      setState(() {
        _loading = true;
      });
      await _authgear.authenticate(redirectURI: redirectURI, page: _page);
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
      await _authgear.reauthenticate(redirectURI: redirectURI);
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

    setState(() {
      _authgear = authgear;
      _sub = _authgear.onSessionStateChange.listen((e) {
        setState(() {});
      });
    });
  }

  Future<void> _onPressOpenSettings(BuildContext context) async {
    try {
      setState(() {
        _loading = true;
      });
      await _authgear.open(SettingsPage.settings);
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

  void onError(BuildContext context, dynamic e) {
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
