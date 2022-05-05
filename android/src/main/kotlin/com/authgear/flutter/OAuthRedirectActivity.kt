package com.authgear.flutter

import android.app.Activity
import android.net.Uri
import android.os.Bundle

class OAuthRedirectActivity: Activity() {
    companion object {
        internal var redirectURI: Uri? = null

        fun registerRedirectURI(uri: Uri) {
            redirectURI = uri
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uri = intent.data
        if (uri != null) {
            if (AuthgearPlugin.onWechatRedirectURI(uri)) {
                // handled
            } else if (isRedirectURI(uri)) {
                startActivity(OAuthCoordinatorActivity.createRedirectIntent(this, uri))
                redirectURI = null
            }
        }
        finish()
    }

    private fun isRedirectURI(uri: Uri): Boolean {
        if (redirectURI == null) {
            return false
        }
        val withoutQuery = uri.buildUpon().clearQuery().build()
        return withoutQuery == redirectURI
    }
}