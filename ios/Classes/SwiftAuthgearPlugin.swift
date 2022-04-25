import Flutter
import UIKit
import AuthenticationServices

public class SwiftAuthgearPlugin: NSObject, FlutterPlugin, ASWebAuthenticationPresentationContextProviding {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_authgear", binaryMessenger: registrar.messenger())
    let instance = SwiftAuthgearPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authenticate":
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let urlString = arguments["url"] as! String
      let redirectURIString = arguments["redirectURI"] as! String
      let preferEphemeral = arguments["preferEphemeral"] as! Bool
      let url = URL(string: urlString)
      let redirectURI = URL(string: redirectURIString)
      self.authenticate(url: url, redirectURI: redirectURI, preferEphemeral: preferEphemeral, result: result)
    case "getDeviceInfo":
      self.getDeviceInfo(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func authenticate(url: URL?, redirectURI: URL?, preferEphemeral: Bool, result: @escaping FlutterResult) {
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

      result(FlutterError.unreachable)
      return
    }

    if #available(iOS 12, *) {
      let session = ASWebAuthenticationSession(
        url: url!,
        callbackURLScheme: redirectURI?.scheme,
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

  @available(iOS 12.0, *)
  public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
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

fileprivate extension FlutterError {
  static var unreachable: FlutterError {
    return FlutterError(code: "UNREACHABLE", message: "unreachable", details: nil)
  }

  static var cancel: FlutterError {
    return FlutterError(code: "CANCEL", message: "cancel", details: nil)
  }

  static var unsupported: FlutterError {
    return FlutterError(code: "UNSUPPORTED", message: "flutter_authgear supports iOS >= 12", details: nil)
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
