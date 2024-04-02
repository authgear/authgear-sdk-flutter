import Flutter
import UIKit
import AuthenticationServices
import LocalAuthentication
import CommonCrypto

public class SwiftAuthgearPlugin: NSObject, FlutterPlugin, ASWebAuthenticationPresentationContextProviding, AGWKWebViewControllerPresentationContextProviding {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_authgear", binaryMessenger: registrar.messenger())
    let instance = SwiftAuthgearPlugin(binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
  }

  public static func wechatFlutterError(errCode: Int32, errStr: String) -> FlutterError {
    return FlutterError(wechatErrCode: errCode, errStr: errStr)
  }

  private var wechatRedirectURIToMethodChannel: [String: String]
  private let binaryMessenger: FlutterBinaryMessenger

  internal init(binaryMessenger: FlutterBinaryMessenger) {
    self.wechatRedirectURIToMethodChannel = [String: String]()
    self.binaryMessenger = binaryMessenger
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "registerWechatRedirectURI":
      self.storeWechat(arguments: call.arguments)
      result(nil)
    case "openAuthorizeURL":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let urlString = arguments["url"] as! String
      let redirectURIString = arguments["redirectURI"] as! String
      let preferEphemeral = arguments["preferEphemeral"] as! Bool
      let url = URL(string: urlString)!
      let redirectURI = URL(string: redirectURIString)!
      self.openAuthorizeURL(url: url, redirectURI: redirectURI, preferEphemeral: preferEphemeral, result: result)
    case "openAuthorizeURLWithWebView":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let url = URL(string: arguments["url"] as! String)!
      let redirectURI = URL(string: arguments["redirectURI"] as! String)!
      let modalPresentationStyle = UIModalPresentationStyle.from(string: arguments["modalPresentationStyle"] as? String)
      let navigationBarBackgroundColor = UIColor(argb: arguments["navigationBarBackgroundColor"] as? String)
      let navigationBarButtonTintColor = UIColor(argb: arguments["navigationBarButtonTintColor"] as? String)
      let isInspectable = arguments["iosIsInspectable"] as? Bool
      self.openAuthorizeURLWithWebView(
        url: url,
        redirectURI: redirectURI,
        modalPresentationStyle: modalPresentationStyle,
        navigationBarBackgroundColor: navigationBarBackgroundColor,
        navigationBarButtonTintColor: navigationBarButtonTintColor,
        isInspectable: isInspectable,
        result: result
      )
    case "openURL":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let urlString = arguments["url"] as! String
      let url = URL(string: urlString)!
      self.openURL(url: url, result: result);
    case "getDeviceInfo":
      self.getDeviceInfo(result: result)
    case "storageSetItem":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let key = arguments["key"] as! String
      let value = arguments["value"] as! String
      self.storageSetItem(key: key, value: value, result: result)
    case "storageGetItem":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let key = arguments["key"] as! String
      self.storageGetItem(key: key, result: result)
    case "storageDeleteItem":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let key = arguments["key"] as! String
      self.storageDeleteItem(key: key, result: result)
    case "generateUUID":
      self.generateUUID(result: result)
    case "checkBiometricSupported":
      self.checkBiometricSupported(result: result)
    case "createBiometricPrivateKey":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      self.createBiometricPrivateKey(arguments: arguments, result: result)
    case "removeBiometricPrivateKey":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let kid = arguments["kid"] as! String
      self.removeBiometricPrivateKey(kid: kid, result: result)
    case "signWithBiometricPrivateKey":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      self.signWithBiometricPrivateKey(arguments: arguments, result: result)
    case "createAnonymousPrivateKey":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let kid = arguments["kid"] as! String
      let payload = arguments["payload"] as! [String: Any]
      self.createAnonymousPrivateKey(kid: kid, payload: payload, result: result)
    case "removeAnonymousPrivateKey":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let kid = arguments["kid"] as! String
      self.removeAnonymousPrivateKey(kid: kid, result: result)
    case "signWithAnonymousPrivateKey":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let kid = arguments["kid"] as! String
      let payload = arguments["payload"] as! [String: Any]
      self.signWithAnonymousPrivateKey(kid: kid, payload: payload, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    return self.handleWechatRedirectURI(url: url)
  }

  public func application(
    _ application: UIApplication,
    open url: URL,
    sourceApplication: String,
    annotation: Any
  ) -> Bool {
    return self.handleWechatRedirectURI(url: url)
  }

  public func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([Any]) -> Void
  ) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL else {
      return false
    }
    return self.handleWechatRedirectURI(url: url)
  }

  private func storeWechat(arguments: Any?) {
    guard let arguments = arguments as? Dictionary<String, AnyObject> else {
      return
    }

    guard
      let wechatRedirectURI = arguments["wechatRedirectURI"] as? String,
      let wechatMethodChannel = arguments["wechatMethodChannel"] as? String
    else {
      return
    }

    self.wechatRedirectURIToMethodChannel[wechatRedirectURI] = wechatMethodChannel
  }

  private func handleWechatRedirectURI(url: URL) -> Bool {
    guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return false
    }

    urlComponents.query = nil
    urlComponents.fragment = nil

    guard let urlWithoutQuery = urlComponents.string else {
      return false
    }

    guard let methodChannel = wechatRedirectURIToMethodChannel.removeValue(forKey: urlWithoutQuery) else {
      return false
    }

    let channel = FlutterMethodChannel(name: methodChannel, binaryMessenger: self.binaryMessenger)
    channel.invokeMethod("onWechatRedirectURI", arguments: url.absoluteString)
    return true
  }

  private func openAuthorizeURL(url: URL, redirectURI: URL, preferEphemeral: Bool, result: @escaping FlutterResult) {
    var sessionToKeepAlive: Any? = nil
    let completionHandler = { (url: URL?, error: Error?) in
      sessionToKeepAlive = nil
      if let error = error {
        if #available(iOS 12, *) {
          if case ASWebAuthenticationSessionError.canceledLogin = error {
            result(FlutterError.cancel)
            return
          }
        }

        self.handleError(result: result, error: error)
        return
      }

      if let url = url {
        result(url.absoluteString)
        return
      }

      result(FlutterError.cancel)
      return
    }

    if #available(iOS 12, *) {
      let session = ASWebAuthenticationSession(
        url: url,
        callbackURLScheme: redirectURI.scheme,
        completionHandler: completionHandler
      )
      if #available(iOS 13, *) {
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = preferEphemeral
      }
      session.start()
      sessionToKeepAlive = session
    } else {
      result(FlutterError.unsupported)
    }
  }

  private func openAuthorizeURLWithWebView(
    url: URL,
    redirectURI: URL,
    modalPresentationStyle: UIModalPresentationStyle,
    navigationBarBackgroundColor: UIColor?,
    navigationBarButtonTintColor: UIColor?,
    isInspectable: Bool?,
    result: @escaping FlutterResult
  ) {
      let controller = AGWKWebViewController(url: url, redirectURI: redirectURI, isInspectable: isInspectable ?? false) { resultURL, error in
          if let error = error {
              let nsError = error as NSError
              if nsError.domain == AGWKWebViewControllerErrorDomain && nsError.code == AGWKWebViewControllerErrorCodeCanceledLogin {
                  result(FlutterError.cancel)
                  return
              }

              self.handleError(result: result, error: error)
              return
          }

          if let resultURL = resultURL {
            result(resultURL.absoluteString)
            return
          }

          result(FlutterError.cancel)
          return
      }
      controller.navigationBarBackgroundColor = navigationBarBackgroundColor
      controller.navigationBarButtonTintColor = navigationBarButtonTintColor
      controller.modalPresentationStyle = modalPresentationStyle
      controller.presentationContextProvider = self
      controller.start()
  }

  private func openURL(url: URL, result: @escaping FlutterResult) {
    var sessionToKeepAlive: Any? = nil
    let completionHandler = { (url: URL?, error: Error?) in
      sessionToKeepAlive = nil
      if let error = error {
        if #available(iOS 12, *) {
          if case ASWebAuthenticationSessionError.canceledLogin = error {
            result(nil)
            return
          }
        }

        self.handleError(result: result, error: error)
        return
      }

      result(FlutterError.cancel)
      return
    }
    if #available(iOS 12, *) {
      let session = ASWebAuthenticationSession(
        url: url,
        callbackURLScheme: "authgearsdk",
        completionHandler: completionHandler
      )
      if #available(iOS 13, *) {
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
      }
      session.start()
      sessionToKeepAlive = session
    } else {
      result(FlutterError.unsupported)
    }
  }

  private func getDeviceInfo(result: FlutterResult) {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machine = withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        ptr in String(validatingUTF8: ptr)
      }
    }!
    let nodename = withUnsafePointer(to: &systemInfo.nodename) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        ptr in String(validatingUTF8: ptr)
      }
    }!
    let release = withUnsafePointer(to: &systemInfo.release) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        ptr in String(validatingUTF8: ptr)
      }
    }!
    let sysname = withUnsafePointer(to: &systemInfo.sysname) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        ptr in String(validatingUTF8: ptr)
      }
    }!
    let version = withUnsafePointer(to: &systemInfo.version) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        ptr in String(validatingUTF8: ptr)
      }
    }!

    let unameDict = [
      "machine": machine,
      "nodename": nodename,
      "release": release,
      "sysname": sysname,
      "version": version,
    ]

    let uiDeviceDict = [
      "name": UIDevice.current.name,
      "systemName": UIDevice.current.systemName,
      "systemVersion": UIDevice.current.systemVersion,
      "model": UIDevice.current.model,
      "userInterfaceIdiom": UIDevice.current.userInterfaceIdiom.name,
    ]

    var nsProcessInfoDict = [
      "isMacCatalystApp": false,
      "isiOSAppOnMac": false,
    ]
    if #available(iOS 13, *) {
      let info = ProcessInfo.processInfo
      nsProcessInfoDict["isMacCatalystApp"] = info.isMacCatalystApp
      if #available(iOS 14, *) {
        nsProcessInfoDict["isiOSAppOnMac"] = info.isiOSAppOnMac
      }
    }

    let infoDictionary = Bundle.main.infoDictionary!
    let nsBundleDict = [
      "CFBundleIdentifier": infoDictionary["CFBundleIdentifier"],
      "CFBundleName": infoDictionary["CFBundleName"],
      "CFBundleDisplayName": infoDictionary["CFBundleDisplayName"],
      "CFBundleExecutable": infoDictionary["CFBundleExecutable"],
      "CFBundleShortVersionString": infoDictionary["CFBundleShortVersionString"],
      "CFBundleVersion": infoDictionary["CFBundleVersion"],
    ]

    let iosDict = [
      "uname": unameDict,
      "UIDevice": uiDeviceDict,
      "NSProcessInfo": nsProcessInfoDict,
      "NSBundle": nsBundleDict,
    ]

    let root = [
      "ios": iosDict,
    ]

    result(root)
  }

  private func storageSetItem(key: String, value: String, result: FlutterResult) {
    let data = value.data(using: .utf8)!
    let updateQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
    ]
    let update: [String: Any] = [
      kSecValueData as String: data,
    ]

    let updateStatus = SecItemUpdate(updateQuery as CFDictionary, update as CFDictionary)
    switch updateStatus {
    case errSecSuccess:
      result(nil)
    default:
      let addQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data,
      ]

      let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
      switch addStatus {
      case errSecSuccess:
        result(nil)
      default:
        result(FlutterError(status: addStatus))
      }
    }
  }

  private func storageGetItem(key: String, result: FlutterResult) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnData as String: true,
    ]

    var item: CFTypeRef?
    let status = withUnsafeMutablePointer(to: &item) {
      SecItemCopyMatching(query as CFDictionary, $0)
    }

    switch status {
    case errSecSuccess:
      let value = String(data: item as! Data, encoding: .utf8)
      result(value)
    case errSecItemNotFound:
      result(nil)
    default:
      result(FlutterError(status: status))
    }
  }

  private func storageDeleteItem(key: String, result: FlutterResult) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
    ]

    let status = SecItemDelete(query as CFDictionary)
    switch status {
    case errSecSuccess:
      result(nil)
    case errSecItemNotFound:
      result(nil)
    default:
      result(FlutterError(status: status))
    }
  }

  private func generateUUID(result: FlutterResult) {
    let uuid = UUID().uuidString
    result(uuid)
  }

  private func checkBiometricSupported(result: @escaping FlutterResult) {
    if #available(iOS 11.3, *) {
      let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
      let laContext = LAContext(policy: policy)
      var nsError: NSError? = nil
      _ = laContext.canEvaluatePolicy(policy, error: &nsError)
      if let nsError = nsError {
        result(FlutterError(nsError: nsError))
      } else {
        result(nil)
      }
    } else {
      result(FlutterError.unsupported)
    }
  }

  private func createBiometricPrivateKey(arguments: [String: AnyObject], result: @escaping FlutterResult) {
    let kid = arguments["kid"] as! String
    let payload = arguments["payload"] as! [String: Any]
    let ios = arguments["ios"] as! [String: Any]
    let constraint = ios["constraint"] as! String
    let localizedReason = ios["localizedReason"] as! String
    let tag = "com.authgear.keys.biometric.\(kid)"

    if #available(iOS 11.3, *) {
      // We intentionally ignore the option.
      // We want to make sure the device owner has biometric
      let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
      let flags = SecAccessControlCreateFlags(constraint: constraint)
      let laContext = LAContext(policy: policy)
      laContext.evaluatePolicy(policy, localizedReason: localizedReason) { _, error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(error: error))
            return
          }

          switch self.generatePrivateKey() {
          case .failure(let error):
            result(FlutterError(error: error))
            return
          case .success(let secKey):
            if let error = self.addBiometricPrivateKey(privateKey: secKey, tag: tag, flags: flags, laContext: laContext) {
              result(FlutterError(error: error))
              return
            }

            switch self.signBiometricJWT(privateKey: secKey, kid: kid, payload: payload) {
            case .failure(let error):
              result(FlutterError(error: error))
              return
            case .success(let jwt):
              result(jwt)
              return
            }
          }
        }
      }
    } else {
      result(FlutterError.unsupported)
    }
  }

  private func removeBiometricPrivateKey(kid: String, result: FlutterResult) {
    let tag = "com.authgear.keys.biometric.\(kid)"
    removePrivateKey(tag: tag, result: result)
  }

  private func removeAnonymousPrivateKey(kid: String, result: FlutterResult) {
    let tag = "com.authgear.keys.anonymous.\(kid)"
    removePrivateKey(tag: tag, result: result)
  }

  private func removePrivateKey(tag: String, result: FlutterResult) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrApplicationTag as String: tag,
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      result(FlutterError(status: status))
      return
    }

    result(nil)
  }

  private func signWithBiometricPrivateKey(arguments: [String: AnyObject], result: @escaping FlutterResult) {
    let kid = arguments["kid"] as! String
    let payload = arguments["payload"] as! [String: Any]
    let ios = arguments["ios"] as! [String: Any]
    let localizedReason = ios["localizedReason"] as! String
    let policyString = ios["policy"] as! String
    let tag = "com.authgear.keys.biometric.\(kid)"

    if #available(iOS 11.3, *) {
      let policy = LAPolicy(policyString: policyString)
      let laContext = LAContext(policy: policy)
      laContext.evaluatePolicy(policy, localizedReason: localizedReason) { _, error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(error: error))
            return
          }

          switch self.getBiometricPrivateKey(tag: tag, laContext: laContext) {
          case .failure(let error):
            result(FlutterError(error: error))
          case .success(let privateKey):
            switch self.signBiometricJWT(privateKey: privateKey, kid: kid, payload: payload) {
            case .failure(let error):
              result(FlutterError(error: error))
            case .success(let jwt):
              result(jwt)
            }
          }
        }
      }
    } else {
      result(FlutterError.unsupported)
    }
  }

  private func createAnonymousPrivateKey(kid: String, payload: [String: Any], result: FlutterResult) {
    let tag = "com.authgear.keys.anonymous.\(kid)"

    if #available(iOS 11.3, *) {
      switch self.generatePrivateKey() {
      case .failure(let error):
        result(FlutterError(error: error))
        return
      case .success(let secKey):
        if let error = self.addAnonymousPrivateKey(privateKey: secKey, tag: tag) {
          result(FlutterError(error: error))
          return
        }

        switch self.signAnonymousJWT(privateKey: secKey, kid: kid, payload: payload) {
        case .failure(let error):
          result(FlutterError(error: error))
          return
        case .success(let jwt):
          result(jwt)
          return
        }
      }
    } else {
      result(FlutterError.unsupported)
    }
  }

  private func signWithAnonymousPrivateKey(kid: String, payload: [String: Any], result: FlutterResult) {
    if #available(iOS 10.0, *) {
      switch self.getAnonymousPrivateKey(kid: kid) {
      case .failure(let error):
        result(FlutterError(error: error))
      case .success(let privateKey):
        switch self.signAnonymousJWT(privateKey: privateKey, kid: kid, payload: payload) {
        case .failure(let error):
          result(FlutterError(error: error))
        case .success(let jwt):
          result(jwt)
        }
      }
    } else {
      result(FlutterError.unsupported)
    }
  }

  @available(iOS 11.3, *)
  private func generatePrivateKey() -> Result<SecKey, Error> {
    var error: Unmanaged<CFError>?
    let query: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrKeySizeInBits as String: 2048,
    ]
    let secKey = SecKeyCreateRandomKey(query as CFDictionary, &error)
    guard let secKey = secKey else {
      return Result.failure(error!.takeRetainedValue() as Error)
    }
    return Result.success(secKey)
  }

  private func addBiometricPrivateKey(privateKey: SecKey, tag: String, flags: SecAccessControlCreateFlags, laContext: LAContext) -> Error? {
    var error: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
      nil,
      kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
      flags,
      &error
    ) else {
      return error!.takeRetainedValue() as Error
    }

    let query: [String: Any] = [
      kSecValueRef as String: privateKey,
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tag,
      kSecAttrAccessControl as String: accessControl,
      kSecUseAuthenticationContext as String: laContext,
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
      return NSError(osStatus: status)
    }

    return nil
  }

  private func addAnonymousPrivateKey(privateKey: SecKey, tag: String) -> Error? {
    let query: [String: Any] = [
      kSecValueRef as String: privateKey,
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tag,
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
      return NSError(osStatus: status)
    }

    return nil
  }

  private func getBiometricPrivateKey(tag: String, laContext: LAContext) -> Result<SecKey, Error> {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrApplicationTag as String: tag,
      kSecReturnRef as String: true,
      kSecUseAuthenticationContext as String: laContext,
    ]

    var item: CFTypeRef?
    let status = withUnsafeMutablePointer(to: &item) {
      SecItemCopyMatching(query as CFDictionary, $0)
    }

    guard status == errSecSuccess else {
      return .failure(NSError(osStatus: status))
    }

    return .success(item as! SecKey)
  }

  private func getAnonymousPrivateKey(kid: String) -> Result<SecKey, Error> {
    let tag = "com.authgear.keys.anonymous.\(kid)"
    return getPrivateKey(tag: tag)
  }

  private func getPrivateKey(tag: String) -> Result<SecKey, Error> {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrApplicationTag as String: tag,
      kSecReturnRef as String: true,
    ]

    var item: CFTypeRef?
    let status = withUnsafeMutablePointer(to: &item) {
      SecItemCopyMatching(query as CFDictionary, $0)
    }

    guard status == errSecSuccess else {
      return .failure(NSError(osStatus: status))
    }

    return .success(item as! SecKey)
  }

  @available(iOS 10.0, *)
  private func signBiometricJWT(privateKey: SecKey, kid: String, payload: [String: Any]) -> Result<String, Error> {
    var jwk: [String: Any] = [:]
    jwk["kid"] = kid

    if let error = getJWKFromPrivateKey(privateKey: privateKey, jwk: &jwk) {
      return .failure(error)
    }

    let header = makeBiometricJWTHeader(jwk: jwk)
    return signJWT(privateKey: privateKey, header: header, payload: payload)
  }

  @available(iOS 10.0, *)
  private func signAnonymousJWT(privateKey: SecKey, kid: String, payload: [String: Any]) -> Result<String, Error> {
    var jwk: [String: Any] = [:]
    jwk["kid"] = kid

    if let error = getJWKFromPrivateKey(privateKey: privateKey, jwk: &jwk) {
      return .failure(error)
    }

    let header = makeAnonymousJWTHeader(jwk: jwk)
    return signJWT(privateKey: privateKey, header: header, payload: payload)
  }

  @available(iOS 10.0, *)
  private func getJWKFromPrivateKey(privateKey: SecKey, jwk: inout [String: Any]) -> Error? {
    var error: Unmanaged<CFError>?

    let publicKey = SecKeyCopyPublicKey(privateKey)!
    guard let cfData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
      return error!.takeRetainedValue() as Error
    }

    let data = cfData as Data

    let n = data.subdata(in: Range(NSRange(location: data.count > 269 ? 9 : 8, length: 256))!)
    let e = data.subdata(in: Range(NSRange(location: data.count - 3, length: 3))!)

    jwk["alg"] = "RS256";
    jwk["kty"] = "RSA";
    jwk["n"] = n.base64urlEncodedString()
    jwk["e"] = e.base64urlEncodedString()

    return nil
  }

  private func makeBiometricJWTHeader(jwk: [String: Any]) -> [String: Any] {
    return [
      "typ": "vnd.authgear.biometric-request",
      "kid": jwk["kid"]!,
      "alg": jwk["alg"]!,
      "jwk": jwk,
    ]
  }

  private func makeAnonymousJWTHeader(jwk: [String: Any]) -> [String: Any] {
    return [
      "typ": "vnd.authgear.anonymous-request",
      "kid": jwk["kid"]!,
      "alg": jwk["alg"]!,
      "jwk": jwk,
    ]
  }

  @available(iOS 10.0, *)
  private func signJWT(privateKey: SecKey, header: [String: Any], payload: [String: Any]) -> Result<String, Error> {
    let headerJSON = JSONSerialization.serialize(value: header)
    let payloadJSON = JSONSerialization.serialize(value: payload)
    let headerString = headerJSON.base64EncodedString()
    let payloadString = payloadJSON.base64EncodedString()
    let strToSign = "\(headerString).\(payloadString)"
    let dataToSign = strToSign.data(using: .utf8)!
    switch self.signData(privateKey: privateKey, data: dataToSign) {
    case .failure(let error):
      return .failure(error)
    case .success(let signature):
      let signatureStr = signature.base64EncodedString()
      let jwt = "\(strToSign).\(signatureStr)"
      return .success(jwt)
    }
  }

  @available(iOS 10.0, *)
  private func signData(privateKey: SecKey, data: Data) -> Result<Data, Error> {
    var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
      _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &buffer)
    }
    var error: Unmanaged<CFError>?
    guard let signedData = SecKeyCreateSignature(privateKey, .rsaSignatureDigestPKCS1v15SHA256, Data(buffer) as CFData, &error) else {
      return .failure(error!.takeRetainedValue() as Error)
    }

    return .success(signedData as Data)
  }

  @available(iOS 12.0, *)
  public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    UIApplication.shared.windows.filter { $0.isKeyWindow }.first!
  }

  func presentationAnchor(for: AGWKWebViewController) -> UIWindow {
    UIApplication.shared.windows.filter { $0.isKeyWindow }.first!
  }

  private func handleError(result: FlutterResult, error: Error) {
    let nsError = error as NSError
    result(FlutterError(
      code: String(nsError.code),
      message: nsError.localizedDescription,
      details: nsError.userInfo
    ))
  }
}

fileprivate extension JSONSerialization {
  static func serialize(value: Any) -> Data {
    let data = try? JSONSerialization.data(withJSONObject: value, options: [])
    return data!
  }
}

fileprivate extension Data {
  func base64urlEncodedString() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

fileprivate extension SecAccessControlCreateFlags {
  @available(iOS 11.3, *)
  init(constraint: String) {
    switch (constraint) {
    case "biometryAny":
      self = [.biometryAny]
    case "biometryCurrentSet":
      self = [.biometryCurrentSet]
    case "userPresence":
      self = [.userPresence]
    default:
      self = []
    }
  }
}

fileprivate extension LAPolicy {
  init(policyString: String) {
    switch (policyString) {
    case "deviceOwnerAuthenticationWithBiometrics":
      self = .deviceOwnerAuthenticationWithBiometrics
    case "deviceOwnerAuthentication":
      self = .deviceOwnerAuthentication
    default:
      self = .deviceOwnerAuthentication
    }
  }
}

fileprivate extension LAContext {
  convenience init(policy: LAPolicy) {
    self.init()
    if case .deviceOwnerAuthenticationWithBiometrics = policy {
      // Hide the fallback button
      // https://developer.apple.com/documentation/localauthentication/lacontext/1514183-localizedfallbacktitle
      self.localizedFallbackTitle = ""
    }
  }
}

fileprivate extension NSError {
  convenience init(osStatus: OSStatus) {
    self.init(domain: NSOSStatusErrorDomain, code: Int(osStatus), userInfo: nil)
  }
}

fileprivate extension FlutterError {
  static var cancel: FlutterError {
    return FlutterError(code: "CANCEL", message: "cancel", details: nil)
  }

  static var unsupported: FlutterError {
    return FlutterError(code: "UNSUPPORTED", message: "flutter_authgear supports iOS >= 12", details: nil)
  }

  convenience init(status: OSStatus) {
    let nsError = NSError(osStatus: status)
    var message = String(status)
    if #available(iOS 11.3, *) {
      if let s = SecCopyErrorMessageString(status, nil) {
        message = s as String
      }
    }
    self.init(code: String(nsError.code), message: message, details: nil)
  }

  convenience init(nsError: NSError) {
    self.init(code: String(nsError.code), message: nsError.localizedDescription, details: nsError.userInfo)
  }

  convenience init(error: Error) {
    let nsError = error as NSError
    self.init(nsError: nsError)
  }

  convenience init(wechatErrCode: Int32, errStr: String) {
    switch wechatErrCode {
    case -2:
      self.init(code: "CANCEL", message: "CANCEL", details: nil)
    default:
      self.init(code: "WechatError", message: errStr, details: [
        "errCode": Int(wechatErrCode),
      ])
    }
  }
}

fileprivate extension UIUserInterfaceIdiom {
  var name: String {
    switch self {
    case .unspecified:
      return "unspecified"
    case .phone:
      return "phone"
    case .pad:
      return "pad"
    case .tv:
      return "tv"
    case .carPlay:
      return "carPlay"
    case .mac:
      return "mac"
    default:
      return "unknown"
    }
  }
}

fileprivate extension UIModalPresentationStyle {
    static func from(string: String?) -> UIModalPresentationStyle {
        if let string = string {
            switch string {
            case "fullScreen":
                return .fullScreen
            case "pageSheet":
                return .pageSheet
            default:
                break
            }
        }
        if #available(iOS 13.0, *) {
            return .automatic
        } else {
            return .fullScreen
        }
    }
}

fileprivate extension UIColor {
    convenience init?(argb: String?) {
        guard let argb = argb else {
            return nil
        }
        let argbInt = UInt32(argb, radix: 16)!
        let a = CGFloat((argbInt >> 24) & 0xFF) / 255.0
        let r = CGFloat((argbInt >> 16) & 0xFF) / 255.0
        let g = CGFloat((argbInt >> 8) & 0xFF) / 255.0
        let b = CGFloat(argbInt & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
