package com.authgear.flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import androidx.browser.customtabs.CustomTabsService

class OAuthCoordinatorActivity: Activity() {
    companion object {
        private const val KEY_AUTHENTICATION_URL = "KEY_AUTHENTICATION_URL"

        internal fun createAuthorizationIntent(context: Context, uri: Uri): Intent {
            val intent = Intent(context, OAuthCoordinatorActivity::class.java)
            intent.putExtra(KEY_AUTHENTICATION_URL, uri.toString());
            return intent;
        }

        internal fun createRedirectIntent(context: Context, uri: Uri): Intent {
            val intent = Intent(context, OAuthCoordinatorActivity::class.java)
            intent.data = uri
            intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            return intent
        }

        private fun getChromePackageName(context: Context): String? {
            val activityIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))
            val resolvedActivities = context.packageManager.queryIntentActivities(activityIntent, 0)
            val packages = ArrayList<String>()
            for (info in resolvedActivities) {
                val serviceIntent = Intent(CustomTabsService.ACTION_CUSTOM_TABS_CONNECTION)
                serviceIntent.setPackage(info.activityInfo.packageName)
                if (context.packageManager.resolveService(serviceIntent, 0) != null) {
                    packages.add(info.activityInfo.packageName)
                }
            }
            if (packages.size == 0) {
                return null
            }
            if (packages.size == 1) {
                return packages[0]
            }
            if (packages.contains("com.android.chrome")) {
                return "com.android.chrome"
            }
            if (packages.contains("com.chrome.beta")) {
                return "com.chrome.beta"
            }
            if (packages.contains("com.chrome.dev")) {
                return "com.chrome.dev"
            }
            if (packages.contains("com.google.android.apps.chrome")) {
                return "com.google.android.apps.chrome"
            }

            return null
        }

    }

    private var webViewActivityStarted = false

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onResume() {
        super.onResume()

        if (!webViewActivityStarted) {
            startWebViewActivity()
            webViewActivityStarted = true
            return
        }

        val uri = intent.data
        if (uri != null) {
            handleRedirect(uri)
        } else {
            handleCancel()
        }

        finish()
    }

    private fun handleRedirect(uri: Uri) {
        val intent = Intent()
        intent.data = uri
        setResult(RESULT_OK, intent)
    }

    private fun handleCancel() {
        val intent = Intent()
        setResult(RESULT_CANCELED, intent)
    }

    private fun startWebViewActivity() {
        val customTabsIntent = CustomTabsIntent.Builder().build()
        val chromePackageName = getChromePackageName(this)

        val uri = Uri.parse(intent.getStringExtra(KEY_AUTHENTICATION_URL))

        val intent = if (chromePackageName == null) {
            Intent(Intent.ACTION_VIEW, uri)
        } else {
            customTabsIntent.intent.setPackage(chromePackageName)
            customTabsIntent.intent.setData(uri)
            customTabsIntent.intent
        }

        startActivity(intent)
    }
}