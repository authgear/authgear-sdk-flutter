package com.authgear.flutter

import android.app.Activity
import android.net.Uri
import android.os.CancellationSignal
import android.util.Log
import android.webkit.WebView
import androidx.core.content.ContextCompat
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.GetCredentialProviderConfigurationException
import androidx.credentials.exceptions.GetCredentialUnsupportedException
import androidx.credentials.exceptions.NoCredentialException
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.net.URI
import java.net.URISyntaxException

// The bridge between AuthUI and the app, as window.authgearBridge in the WebView.
// See docs/specs/webview-bridge.md in authgear-server for the messages.
internal class WebViewBridge(private val activity: Activity) {
    companion object {
        const val OBJECT_NAME = "authgearBridge"
        private const val LOGTAG = "Authgear"
    }

    // The pending credentials.get. Only one runs at a time.
    // Cancelling it cancels the request of Credential Manager, and drops its reply.
    private var pendingGet: CancellationSignal? = null

    fun install(webView: WebView, allowedOrigins: List<Uri>) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
            return
        }
        val rules = try {
            allowedOrigins.mapNotNull { allowedOriginRule(URI(it.toString())) }.toSet()
        } catch (e: URISyntaxException) {
            Log.w(LOGTAG, "authgearBridge is not installed: invalid URL", e)
            return
        }
        if (rules.isEmpty()) {
            Log.w(LOGTAG, "authgearBridge is not installed: no allowed origin")
            return
        }
        // The WebView rejects a rule it cannot parse. Then the page has no bridge.
        try {
            WebViewCompat.addWebMessageListener(
                webView,
                OBJECT_NAME,
                rules
            ) { view, message, sourceOrigin, isMainFrame, replyProxy ->
                val data = message.data
                if (!isMainFrame || data == null) {
                    return@addWebMessageListener
                }
                val request = parseRequest(data) ?: return@addWebMessageListener
                handle(view, request, sourceOrigin, replyProxy)
            }
        } catch (e: IllegalArgumentException) {
            Log.w(LOGTAG, "authgearBridge is not installed: invalid origin rule", e)
        }
    }

    // Cancels the pending requests without replying: the page that sent them is gone.
    fun cancelPending() {
        pendingGet?.cancel()
        pendingGet = null
    }

    private fun handle(
        webView: WebView,
        request: BridgeRequest,
        sourceOrigin: Uri,
        replyProxy: JavaScriptReplyProxy
    ) {
        when (request.type) {
            BridgeMessageType.CAPABILITIES -> replyProxy.postMessage(capabilitiesReply(request.id))
            BridgeMessageType.CREDENTIALS_GET -> credentialsGet(webView, request, sourceOrigin, replyProxy)
            else -> replyProxy.postMessage(reply(request.id, BridgeStatus.UNSUPPORTED))
        }
    }

    private fun credentialsGet(
        webView: WebView,
        request: BridgeRequest,
        sourceOrigin: Uri,
        replyProxy: JavaScriptReplyProxy
    ) {
        val id = request.id
        val mediation = request.json["mediation"]
        val publicKey = request.json["publicKey"]
        // publicKey is the only member supported. Other members, such as password, are ignored.
        if (mediation != JsonPrimitive("immediate") || publicKey == null || publicKey is JsonNull) {
            replyProxy.postMessage(reply(id, BridgeStatus.UNSUPPORTED))
            return
        }
        if (pendingGet != null) {
            replyProxy.postMessage(reply(id, BridgeStatus.ERROR, "a passkey request is in progress"))
            return
        }
        if (publicKey !is JsonObject) {
            replyProxy.postMessage(reply(id, BridgeStatus.ERROR, "publicKey must be an object"))
            return
        }

        val signal = CancellationSignal()
        pendingGet = signal
        getPublicKeyCredential(id, publicKey, signal) { text ->
            // A cancelled request may still call back. Its page is gone, so the reply is dropped.
            if (pendingGet !== signal) {
                return@getPublicKeyCredential
            }
            pendingGet = null
            // onPageStarted is not called for every navigation, so cancelPending() may not have
            // been called. Drop the reply if the WebView no longer shows the page that asked.
            if (!isSameOrigin(webView.url, sourceOrigin.toString())) {
                return@getPublicKeyCredential
            }
            replyProxy.postMessage(text)
        }
    }

    // Calls onReply on the main thread with the reply, unless the request fails to start.
    private fun getPublicKeyCredential(
        id: String,
        publicKey: JsonObject,
        signal: CancellationSignal,
        onReply: (String) -> Unit
    ) {
        try {
            val options = credentialManagerRequestJson(publicKey)
            val request = GetCredentialRequest(
                credentialOptions = listOf(GetPublicKeyCredentialOption(options.toString())),
                preferImmediatelyAvailableCredentials = true
            )
            // The activity is the context, so that the sheet is shown over it.
            CredentialManager.create(activity).getCredentialAsync(
                activity,
                request,
                signal,
                ContextCompat.getMainExecutor(activity),
                object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                    override fun onResult(result: GetCredentialResponse) {
                        onReply(credentialReply(id, result))
                    }

                    override fun onError(e: GetCredentialException) {
                        onReply(credentialErrorReply(id, e))
                    }
                }
            )
        } catch (e: Exception) {
            onReply(reply(id, BridgeStatus.ERROR, e.toString()))
        }
    }

    private fun credentialReply(id: String, result: GetCredentialResponse): String {
        return try {
            when (val credential = result.credential) {
                is PublicKeyCredential -> reply(
                    id,
                    BridgeStatus.OK,
                    fields = mapOf(
                        "credential" to Json.parseToJsonElement(credential.authenticationResponseJson)
                    )
                )
                else -> reply(id, BridgeStatus.ERROR, "unexpected credential type: ${credential.type}")
            }
        } catch (e: Exception) {
            reply(id, BridgeStatus.ERROR, e.toString())
        }
    }

    private fun credentialErrorReply(id: String, e: GetCredentialException): String {
        return when (e) {
            is NoCredentialException -> reply(id, BridgeStatus.NO_CREDENTIAL)
            is GetCredentialCancellationException -> reply(id, BridgeStatus.CANCELLED)
            is GetCredentialProviderConfigurationException -> reply(id, BridgeStatus.UNSUPPORTED)
            is GetCredentialUnsupportedException -> reply(id, BridgeStatus.UNSUPPORTED)
            else -> reply(id, BridgeStatus.ERROR, "${e.type}: ${e.message}")
        }
    }
}

internal object BridgeMessageType {
    const val CAPABILITIES = "bridge.capabilities"
    const val CREDENTIALS_GET = "credentials.get"
}

internal object BridgeStatus {
    const val OK = "ok"
    const val UNSUPPORTED = "unsupported"
    const val ERROR = "error"
    const val NO_CREDENTIAL = "no_credential"
    const val CANCELLED = "cancelled"
}

// The capabilities listed in the reply to bridge.capabilities.
internal val BRIDGE_CAPABILITIES: List<String> = listOf(
    "credentials.get",
    "credentials.get:publicKey",
    "credentials.get:immediate"
)

internal data class BridgeRequest(
    val id: String,
    val type: String?,
    val json: JsonObject
)

// The rule of WebViewCompat.addWebMessageListener that allows the origin of url,
// or null when url has no scheme or host. The authority is not used because it can carry user info.
internal fun allowedOriginRule(url: URI): String? {
    val scheme = url.scheme ?: return null
    val host = url.host ?: return null
    val rule = "$scheme://$host"
    if (url.port != -1) {
        return "$rule:${url.port}"
    }
    return rule
}

internal fun sameOrigin(a: URI, b: URI): Boolean {
    val schemeA = a.scheme?.lowercase() ?: return false
    val schemeB = b.scheme?.lowercase() ?: return false
    val hostA = a.host?.lowercase() ?: return false
    val hostB = b.host?.lowercase() ?: return false
    return schemeA == schemeB && hostA == hostB && portOf(a, schemeA) == portOf(b, schemeB)
}

// False when either is null or not a valid URI.
internal fun isSameOrigin(a: String?, b: String?): Boolean {
    if (a == null || b == null) {
        return false
    }
    return try {
        sameOrigin(URI(a), URI(b))
    } catch (e: URISyntaxException) {
        false
    }
}

private fun portOf(url: URI, scheme: String): Int {
    if (url.port != -1) {
        return url.port
    }
    return when (scheme) {
        "http" -> 80
        "https" -> 443
        else -> -1
    }
}

// Returns null when text is not a JSON object with a string id.
internal fun parseRequest(text: String): BridgeRequest? {
    val json = try {
        Json.parseToJsonElement(text)
    } catch (e: Exception) {
        return null
    }
    if (json !is JsonObject) {
        return null
    }
    val id = json["id"] as? JsonPrimitive ?: return null
    if (!id.isString) {
        return null
    }
    val type = (json["type"] as? JsonPrimitive)?.takeIf { it.isString }?.content
    return BridgeRequest(id.content, type, json)
}

// The fields of publicKey that the spec lets the app use, so that both platforms
// handle the same request the same way. A later field needs its own capability.
internal fun credentialManagerRequestJson(publicKey: JsonObject): JsonObject {
    val fields = mutableMapOf<String, JsonElement>()
    for (key in listOf("challenge", "rpId", "userVerification")) {
        publicKey[key]?.let { fields[key] = it }
    }
    val allowCredentials = publicKey["allowCredentials"]
    if (allowCredentials is JsonArray && allowCredentials.isNotEmpty()) {
        fields["allowCredentials"] = allowCredentials
    }
    return JsonObject(fields)
}

internal fun reply(
    id: String,
    status: String,
    message: String? = null,
    fields: Map<String, JsonElement> = mapOf()
): String {
    val obj = buildJsonObject {
        put("id", id)
        put("status", status)
        if (message != null) {
            put("message", message)
        }
        fields.forEach { (key, value) -> put(key, value) }
    }
    return obj.toString()
}

internal fun capabilitiesReply(id: String): String {
    return reply(
        id,
        BridgeStatus.OK,
        fields = mapOf("capabilities" to JsonArray(BRIDGE_CAPABILITIES.map { JsonPrimitive(it) }))
    )
}
