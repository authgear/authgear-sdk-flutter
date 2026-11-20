import UIKit
import Flutter
import flutter_authgear

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, WXApiDelegate {

  private var wechat = [String: FlutterResult]()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    WXApi.startLog(by: WXLogLevel.detail) { message in
      print("WeChatSDK: \(message)")
    }
    WXApi.registerApp("wxe64ed6a7605b5021", universalLink: "https://authgear-demo-flutter.oursky.codes/wechat/")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // With the UIScene life cycle, the window and its FlutterViewController do not exist yet
  // in application(_:didFinishLaunchingWithOptions:), so plugins and channels are set up here.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(name: "example", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler {
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let state = arguments["state"] as! String
      self.wechat[state] = result
      let req = SendAuthReq()
      req.scope = "snsapi_userinfo"
      req.state = state
      WXApi.send(req)
    }
  }

  @objc
  func onReq(_ req: BaseReq) {
  }

  @objc
  func onResp(_ resp: BaseResp) {
    guard let authResp = resp as? SendAuthResp else {
      return
    }

    guard let state = authResp.state else {
      return
    }

    let errCode = WXErrCode(rawValue: authResp.errCode)
    let errStr = authResp.errStr
    let code = authResp.code

    guard let result = wechat.removeValue(forKey: state) else {
      return
    }

    if errCode == WXSuccess {
      result(code)
    } else {
      result(SwiftAuthgearPlugin.wechatFlutterError(errCode: authResp.errCode, errStr: errStr))
    }
  }
}

// With the UIScene life cycle, URLs and universal links are delivered to the scene delegate
// instead of the application delegate, so the WeChat callbacks are handled here.
// It lives in this file so that the Xcode project does not need another source file.
class SceneDelegate: FlutterSceneDelegate {

  private var wechatDelegate: WXApiDelegate? {
    UIApplication.shared.delegate as? AppDelegate
  }

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // The app was launched by a URL or a universal link.
    for context in connectionOptions.urlContexts {
      WXApi.handleOpen(context.url, delegate: wechatDelegate)
    }
    for userActivity in connectionOptions.userActivities {
      WXApi.handleOpenUniversalLink(userActivity, delegate: wechatDelegate)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      WXApi.handleOpen(context.url, delegate: wechatDelegate)
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    WXApi.handleOpenUniversalLink(userActivity, delegate: wechatDelegate)
    super.scene(scene, continue: userActivity)
  }
}
