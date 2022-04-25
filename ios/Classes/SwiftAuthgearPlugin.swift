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
    default:
        result(FlutterMethodNotImplemented)
    }
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
