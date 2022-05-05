package com.authgear.flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.Menu
import android.view.MenuItem
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.annotation.RequiresApi
import androidx.appcompat.app.AppCompatActivity

class WebViewActivity: AppCompatActivity() {
    companion object {
        private const val MENU_ID_CANCEL = 1
        private const val KEY_URL = "KEY_URL"

        internal fun createIntent(context: Context, url: Uri): Intent {
            val intent = Intent(context, WebViewActivity::class.java)
            intent.putExtra(KEY_URL, url.toString())
            return intent
        }
    }
    private lateinit var webView: WebView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val url = intent.getStringExtra(KEY_URL)!!
        webView = WebView(this)
        setContentView(webView)
        // It is extremely important to set webViewClient,
        // otherwise the default webViewClient is used,
        // which opens the system browser
        webView.webViewClient = object : WebViewClient() {

            @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?
            ): Boolean {
                val url = request?.url
                if (url != null && AuthgearPlugin.onWechatRedirectURI(url)) {
                    return true
                }
                return super.shouldOverrideUrlLoading(view, request)
            }

            override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                if (url != null && AuthgearPlugin.onWechatRedirectURI(Uri.parse(url))) {
                    return true
                }
                return super.shouldOverrideUrlLoading(view, url)
            }
        }
        webView.settings?.javaScriptEnabled = true
        webView.loadUrl(url)
    }

    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }

    override fun onCreateOptionsMenu(menu: Menu?): Boolean {
        menu?.add(
            Menu.NONE,
            MENU_ID_CANCEL,
            Menu.NONE,
            android.R.string.cancel
        )
            ?.setIcon(android.R.drawable.ic_menu_close_clear_cancel)
            ?.setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
        return super.onCreateOptionsMenu(menu)
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        if (item.itemId == MENU_ID_CANCEL) {
            setResult(Activity.RESULT_CANCELED)
            finish()
            return true
        }
        return super.onOptionsItemSelected(item)
    }
}