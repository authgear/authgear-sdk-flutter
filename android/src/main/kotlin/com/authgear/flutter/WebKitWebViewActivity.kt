package com.authgear.flutter

import android.annotation.TargetApi
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Message
import android.view.Menu
import android.view.MenuItem
import android.webkit.*
import android.webkit.WebView.HitTestResult.SRC_ANCHOR_TYPE
import android.webkit.WebView.HitTestResult.SRC_IMAGE_ANCHOR_TYPE
import androidx.annotation.*
import androidx.appcompat.app.ActionBar
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.res.ResourcesCompat
import androidx.core.graphics.drawable.DrawableCompat

class WebKitWebViewActivity: AppCompatActivity() {
    companion object {
        private const val MENU_ID_CANCEL = 1
        private const val KEY_OPTIONS = "KEY_OPTIONS"
        private const val KEY_WEB_VIEW_STATE = "KEY_WEB_VIEW_STATE"
        private const val TAG_FILE_CHOOSER = 1
        internal const val KEY_WECHAT_REDIRECT_URI = "KEY_WECHAT_REDIRECT_URI"

        fun createIntent(ctx: Context, options: Options): Intent {
            val intent = Intent(ctx, WebKitWebViewActivity::class.java)
            intent.putExtra(KEY_OPTIONS, options.toBundle())
            return intent
        }
    }

    private lateinit var mWebView: WebView
    private var result: Uri? = null
    private val handles = StartActivityHandles<ValueCallback<Array<Uri>>>()

    class Options {
        var url: Uri
        var redirectURI: Uri
        var actionBarBackgroundColor: Int? = null
        var actionBarButtonTintColor: Int? = null
        var wechatRedirectURI: Uri? = null
        var wechatRedirectURIIntentAction: String? = null

        constructor(url: Uri, redirectURI: Uri) {
            this.url = url
            this.redirectURI = redirectURI
        }

        internal constructor(bundle: Bundle) {
            this.url = bundle.getParcelable("url")!!
            this.redirectURI = bundle.getParcelable("redirectURI")!!
            if (bundle.containsKey("actionBarBackgroundColor")) {
                this.actionBarBackgroundColor = bundle.getInt("actionBarBackgroundColor")
            }
            if (bundle.containsKey("actionBarButtonTintColor")) {
                this.actionBarButtonTintColor = bundle.getInt("actionBarButtonTintColor")
            }
            if (bundle.containsKey("wechatRedirectURI")) {
                this.wechatRedirectURI = bundle.getParcelable("wechatRedirectURI")
            }
            if (bundle.containsKey("wechatRedirectURIIntentAction")) {
                this.wechatRedirectURIIntentAction = bundle.getString("wechatRedirectURIIntentAction")
            }
        }

        fun toBundle(): Bundle {
            val bundle = Bundle()
            bundle.putParcelable("url", this.url)
            bundle.putParcelable("redirectURI", this.redirectURI)
            this.actionBarBackgroundColor?.let {
                bundle.putInt("actionBarBackgroundColor", it)
            }
            this.actionBarButtonTintColor?.let {
                bundle.putInt("actionBarButtonTintColor", it)
            }
            this.wechatRedirectURI?.let {
                bundle.putParcelable("wechatRedirectURI", it)
            }
            this.wechatRedirectURIIntentAction?.let {
                bundle.putString("wechatRedirectURIIntentAction", it)
            }
            return bundle
        }
    }

    private class MyWebViewClient constructor(private val activity: WebKitWebViewActivity) :
        WebViewClient() {

        companion object {
            private const val USERSCRIPT_USER_SELECT_NONE = "document.documentElement.style.webkitUserSelect='none';document.documentElement.style.userSelect='none';";
        }

        override fun onPageFinished(view: WebView?, url: String?) {
            super.onPageFinished(view, url)
            // android.webkit.view does not have WKUserContentController that allows us to inject userscript.
            // onPageFinished will be called for each navigation.
            // So it can be used as a replacement of WKUserContentController to allow us to
            // run a script for every page.
            // The caveat is that the script is run in the main frame only.
            // But we do not actually use iframes so it does not matter.
            view?.evaluateJavascript(USERSCRIPT_USER_SELECT_NONE, null);
        }

        @TargetApi(Build.VERSION_CODES.N)
        override fun shouldOverrideUrlLoading(
            view: WebView?,
            request: WebResourceRequest?
        ): Boolean {
            val uri = request?.url!!
            if (this.shouldOverrideUrlLoading(uri)) {
                return true
            }
            return super.shouldOverrideUrlLoading(view, request)
        }

        @SuppressWarnings("deprecation")
        override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
            val uri = Uri.parse(url!!)!!
            if (this.shouldOverrideUrlLoading(uri)) {
                return true
            }
            return super.shouldOverrideUrlLoading(view, url)
        }

        private fun shouldOverrideUrlLoading(uri: Uri): Boolean {
            val withoutQuery = this.removeQueryAndFragment(uri)

            val redirectURI = this.activity.getOptions().redirectURI
            if (withoutQuery.toString() ==  redirectURI.toString()) {
                this.activity.result = uri
                this.activity.callSetResult()
                this.activity.finish()
                return true
            }

            val wechatRedirectURI = this.activity.getOptions().wechatRedirectURI
            if (wechatRedirectURI != null) {
                if (withoutQuery.toString() == wechatRedirectURI.toString()) {
                    val intent = Intent(this.activity.getOptions().wechatRedirectURIIntentAction)
                    intent.setPackage(this.activity.applicationContext.packageName)
                    intent.putExtra(KEY_WECHAT_REDIRECT_URI, uri)
                    this.activity.applicationContext.sendBroadcast(intent)
                    return true
                }
            }

            return false;
        }

        private fun removeQueryAndFragment(uri: Uri): Uri {
            return uri.buildUpon().query(null).fragment(null).build()
        }
    }

    private class MyWebChromeClient constructor(private val activity: WebKitWebViewActivity) :
        WebChromeClient() {

        @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
        override fun onShowFileChooser(
            webView: WebView?,
            filePathCallback: ValueCallback<Array<Uri>>?,
            fileChooserParams: FileChooserParams?
        ): Boolean {
            val handle = StartActivityHandle(TAG_FILE_CHOOSER, filePathCallback!!)
            val requestCode = this.activity.handles.push(handle)
            val intent = fileChooserParams!!.createIntent()
            this.activity.startActivityForResult(intent, requestCode)
            return true
        }

        override fun onCreateWindow(
            view: WebView?,
            isDialog: Boolean,
            isUserGesture: Boolean,
            resultMsg: Message?
        ): Boolean {
            if (view == null) return false
            val result = view.hitTestResult
            return when (result.type) {
                SRC_IMAGE_ANCHOR_TYPE -> {
                    // ref: https://pacheco.dev/posts/android/webview-image-anchor/
                    val handler = view.handler
                    val message = handler.obtainMessage()
                    view.requestFocusNodeHref(message)
                    val url = message.data.getString("url") ?: return false
                    val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    view.context.startActivity(browserIntent)
                    return false
                }
                SRC_ANCHOR_TYPE -> {
                    val data = result.extra ?: return false
                    val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(data))
                    view.context.startActivity(browserIntent)
                    return false
                }
                else -> false
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val options = this.getOptions()

        // Do not show title.
        supportActionBar?.setDisplayShowTitleEnabled(false)

        // Configure navigation bar background color.
        options.actionBarBackgroundColor?.let {
            supportActionBar?.setBackgroundDrawable(ColorDrawable(it))
        }

        // Show back button.
        supportActionBar?.displayOptions = ActionBar.DISPLAY_SHOW_HOME or ActionBar.DISPLAY_HOME_AS_UP

        // Configure the back button.
        var backButtonDrawable = getDrawableCompat(R.drawable.ic_arrow_back)
        if (options.actionBarButtonTintColor != null) {
            backButtonDrawable =
                tintDrawable(backButtonDrawable, options.actionBarButtonTintColor!!)
        }
        supportActionBar?.setHomeAsUpIndicator(backButtonDrawable)

        // Configure web view.
        this.mWebView = WebView(this)
        this.mWebView.settings.setSupportMultipleWindows(true)
        this.mWebView.settings.domStorageEnabled = true
        this.mWebView.settings.javaScriptEnabled = true
        this.setContentView(this.mWebView)
        this.mWebView.setWebViewClient(MyWebViewClient(this))
        this.mWebView.setWebChromeClient(MyWebChromeClient(this))

        if (savedInstanceState == null) {
            this.mWebView.loadUrl(options.url.toString())
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        val webViewBundle = Bundle()
        this.mWebView.saveState(webViewBundle)
        outState.putBundle(KEY_WEB_VIEW_STATE, webViewBundle)
    }

    override fun onRestoreInstanceState(savedInstanceState: Bundle) {
        super.onRestoreInstanceState(savedInstanceState)
        val bundle = savedInstanceState.getBundle(KEY_WEB_VIEW_STATE)
        if (bundle != null) {
            this.mWebView.restoreState(bundle)
        }
    }

    override fun onBackPressed() {
        if (mWebView.canGoBack()) {
            mWebView.goBack()
        } else {
            callSetResult()
            super.onBackPressed()
        }
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        val options = getOptions()

        // Configure the close button.
        var drawable = getDrawableCompat(R.drawable.ic_close)
        if (options.actionBarButtonTintColor != null) {
            drawable = tintDrawable(drawable, options.actionBarButtonTintColor!!)
        }
        menu.add(Menu.NONE, MENU_ID_CANCEL, Menu.NONE, android.R.string.cancel)
            .setIcon(drawable)
            .setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
        return super.onCreateOptionsMenu(menu)
    }

    override fun onOptionsItemSelected(@NonNull item: MenuItem): Boolean {
        if (item.getItemId() === android.R.id.home) {
            onBackPressed()
            return true
        }
        if (item.getItemId() === MENU_ID_CANCEL) {
            callSetResult()
            finish()
            return true
        }
        return super.onOptionsItemSelected(item)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, @Nullable data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val handle = handles.pop(requestCode)
            ?: return
        when (handle.tag) {
            TAG_FILE_CHOOSER -> when (resultCode) {
                Activity.RESULT_CANCELED -> handle.value.onReceiveValue(null)
                Activity.RESULT_OK -> if (data != null && data.data != null) {
                    handle.value.onReceiveValue(arrayOf(data.data!!))
                } else {
                    handle.value.onReceiveValue(null)
                }
            }
        }
    }

    private fun getOptions(): Options {
        val bundle: Bundle = this.intent.getParcelableExtra(KEY_OPTIONS)!!
        return Options(bundle)
    }

    private fun callSetResult() {
        if (this.result == null) {
            this.setResult(Activity.RESULT_CANCELED)
        } else {
            val intent = Intent()
            intent.data = this.result
            this.setResult(Activity.RESULT_OK, intent)
        }
    }

    private fun getDrawableCompat(@DrawableRes id: Int): Drawable {
        return ResourcesCompat.getDrawable(resources, id, null)!!
    }

    private fun tintDrawable(drawable: Drawable, @ColorInt color: Int): Drawable {
        val newDrawable: Drawable =
            DrawableCompat.wrap(drawable).constantState!!.newDrawable().mutate()
        DrawableCompat.setTint(newDrawable, color)
        return newDrawable
    }
}