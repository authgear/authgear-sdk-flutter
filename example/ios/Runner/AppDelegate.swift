import UIKit
import Flutter
import flutter_authgear

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, WXApiDelegate {

  private var wechat = [String: FlutterResult]()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    WXApi.startLog(by: WXLogLevel.detail) { message in
      print("WeChatSDK: \(message)")
    }
    WXApi.registerApp("wxe64ed6a7605b5021", universalLink: "https://authgear-demo-flutter.pandawork.com/wechat/")

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "example", binaryMessenger: controller.binaryMessenger)
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

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    WXApi.handleOpenUniversalLink(userActivity, delegate: self)
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
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
