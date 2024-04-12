package com.authgear.exampleapp.flutter

import com.tencent.mm.opensdk.modelmsg.SendAuth
import com.tencent.mm.opensdk.openapi.IWXAPI
import com.tencent.mm.opensdk.openapi.WXAPIFactory
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel


class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "example"

    companion object {
        internal val WECHAT_APP_ID = "wxe64ed6a7605b5021"
        private val wechat: HashMap<String, MethodChannel.Result> = hashMapOf()

        internal fun storeWechat(state: String, result: MethodChannel.Result) {
            wechat[state] = result
        }

        internal fun popWechat(state: String): MethodChannel.Result? {
            return wechat.remove(state)
        }
    }

    private var api: IWXAPI? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        api = WXAPIFactory.createWXAPI(this, WECHAT_APP_ID)
        api?.registerApp(WECHAT_APP_ID)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val api = api!!
        if (!api.isWXAppInstalled) {
            result.error("WechatError", "wechat is not installed", null)
            return
        }

        val state = call.argument<String>("state")!!
        val req = SendAuth.Req()
        req.scope = "snsapi_userinfo"
        req.state = state
        storeWechat(state, result)
        api.sendReq(req)
    }
}
