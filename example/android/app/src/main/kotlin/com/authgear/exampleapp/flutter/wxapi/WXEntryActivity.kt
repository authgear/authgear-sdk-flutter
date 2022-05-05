package com.authgear.exampleapp.flutter.wxapi

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.authgear.exampleapp.flutter.MainActivity
import com.authgear.flutter.AuthgearPlugin
import com.tencent.mm.opensdk.modelbase.BaseReq
import com.tencent.mm.opensdk.modelbase.BaseResp
import com.tencent.mm.opensdk.modelmsg.SendAuth
import com.tencent.mm.opensdk.openapi.IWXAPI
import com.tencent.mm.opensdk.openapi.IWXAPIEventHandler
import com.tencent.mm.opensdk.openapi.WXAPIFactory

class WXEntryActivity: Activity(), IWXAPIEventHandler {
    private var api: IWXAPI? = null;

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        api = WXAPIFactory.createWXAPI(this, MainActivity.WECHAT_APP_ID)
        api?.registerApp(MainActivity.WECHAT_APP_ID)

        if (this.intent != null) {
            api?.handleIntent(this.intent, this)
        }
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)

        setIntent(intent)
        if (intent != null) {
            api?.handleIntent(intent, this)
        }
    }

    override fun onReq(req: BaseReq?) {
        finish()
    }

    override fun onResp(resp: BaseResp?) {
        if (resp == null) {
            return
        }

        if (resp is SendAuth.Resp) {
            val state = resp.state
            val code = resp.code
            val errCode = resp.errCode
            val errStr = resp.errStr

            val result = MainActivity.popWechat(state)
            if (result != null) {
                if (errCode == BaseResp.ErrCode.ERR_OK) {
                    result.success(code)
                } else {
                    AuthgearPlugin.wechatErrorResult(errCode, errStr, result)
                }
            }
        }

        finish()
    }
}