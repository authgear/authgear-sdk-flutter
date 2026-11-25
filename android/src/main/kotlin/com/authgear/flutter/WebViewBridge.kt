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
import kotlinx.serialization.SerializationException
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
import java.util.Locale

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
            BridgeMessageType.CAPABILITIES -> replyProxy.postMessage(capabilitiesReply(request.id).encode())
            BridgeMessageType.CREDENTIALS_GET -> credentialsGet(webView, request, sourceOrigin, replyProxy)
            else -> replyProxy.postMessage(BridgeReply(request.id, BridgeStatus.UNSUPPORTED).encode())
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
            replyProxy.postMessage(BridgeReply(id, BridgeStatus.UNSUPPORTED).encode())
            return
        }
        if (pendingGet != null) {
            replyProxy.postMessage(BridgeReply(id, BridgeStatus.ERROR, "a passkey request is in progress").encode())
            return
        }
        if (publicKey !is JsonObject) {
            replyProxy.postMessage(BridgeReply(id, BridgeStatus.ERROR, "publicKey must be an object").encode())
            return
        }
        // As in a browser, rpId must be the page's host or a parent domain of it.
        val rpId = (publicKey["rpId"] as? JsonPrimitive)?.takeIf { it.isString }?.content
        val host = sourceOrigin.host
        if (rpId == null || host == null || !isRpIdAllowed(rpId, host)) {
            replyProxy.postMessage(BridgeReply(id, BridgeStatus.ERROR, "rpId is not allowed for this page").encode())
            return
        }

        val signal = CancellationSignal()
        pendingGet = signal
        getPublicKeyCredential(id, publicKey, signal) { reply ->
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
            replyProxy.postMessage(reply.encode())
        }
    }

    // Calls onReply on the main thread with the reply, unless the request fails to start.
    private fun getPublicKeyCredential(
        id: String,
        publicKey: JsonObject,
        signal: CancellationSignal,
        onReply: (BridgeReply) -> Unit
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
            onReply(BridgeReply(id, BridgeStatus.ERROR, e.toString()))
        }
    }

    private fun credentialReply(id: String, result: GetCredentialResponse): BridgeReply {
        return when (val credential = result.credential) {
            is PublicKeyCredential -> {
                val parsed = BridgePublicKeyCredential.parse(credential.authenticationResponseJson)
                if (parsed != null) {
                    BridgeReply(id, BridgeStatus.OK, credential = parsed)
                } else {
                    BridgeReply(id, BridgeStatus.ERROR, "invalid authenticationResponseJson")
                }
            }
            else -> BridgeReply(id, BridgeStatus.ERROR, "unexpected credential type: ${credential.type}")
        }
    }

    private fun credentialErrorReply(id: String, e: GetCredentialException): BridgeReply {
        return when (e) {
            is NoCredentialException -> BridgeReply(id, BridgeStatus.NO_CREDENTIAL)
            is GetCredentialCancellationException -> BridgeReply(id, BridgeStatus.CANCELLED)
            is GetCredentialProviderConfigurationException -> BridgeReply(id, BridgeStatus.UNSUPPORTED)
            is GetCredentialUnsupportedException -> BridgeReply(id, BridgeStatus.UNSUPPORTED)
            else -> BridgeReply(id, BridgeStatus.ERROR, "${e.type}: ${e.message}")
        }
    }
}

internal object BridgeMessageType {
    const val CAPABILITIES = "bridge.capabilities"
    const val CREDENTIALS_GET = "credentials.get"
}

// The status of a reply. A new status is a new entry.
internal enum class BridgeStatus(val value: String) {
    OK("ok"),
    UNSUPPORTED("unsupported"),
    ERROR("error"),
    NO_CREDENTIAL("no_credential"),
    CANCELLED("cancelled"),
}

// A reply, encoded as a JSON object. Fields that are null are omitted.
// A new field is a new property, encoded in toJson.
internal data class BridgeReply(
    val id: String,
    val status: BridgeStatus,
    val message: String? = null,
    // The ok reply to bridge.capabilities.
    val capabilities: List<String>? = null,
    // The ok reply to credentials.get.
    val credential: BridgeCredential? = null,
) {
    fun toJson(): JsonObject = buildJsonObject {
        put("id", id)
        put("status", status.value)
        message?.let { put("message", it) }
        capabilities?.let { list -> put("capabilities", JsonArray(list.map { JsonPrimitive(it) })) }
        credential?.let { put("credential", it.toJson()) }
    }

    fun encode(): String = toJson().toString()
}

// The credential of an ok reply to credentials.get. Each kind of credential, told apart by
// its type, is a class that implements this interface.
internal sealed interface BridgeCredential {
    fun toJson(): JsonObject
}

// The AuthenticationResponseJSON of a passkey assertion, with binary values as base64url.
internal data class BridgePublicKeyCredential(
    val id: String,
    val rawId: String,
    val authenticatorAttachment: String?,
    val response: Response,
    val clientExtensionResults: JsonObject,
) : BridgeCredential {
    data class Response(
        val clientDataJSON: String,
        val authenticatorData: String,
        val signature: String,
        // Optional in AuthenticationResponseJSON.
        val userHandle: String?,
    )

    override fun toJson(): JsonObject = buildJsonObject {
        put("id", id)
        put("rawId", rawId)
        put("type", TYPE)
        authenticatorAttachment?.let { put("authenticatorAttachment", it) }
        put(
            "response",
            buildJsonObject {
                put("clientDataJSON", response.clientDataJSON)
                put("authenticatorData", response.authenticatorData)
                put("signature", response.signature)
                response.userHandle?.let { put("userHandle", it) }
            }
        )
        put("clientExtensionResults", clientExtensionResults)
    }

    companion object {
        const val TYPE = "public-key"

        // Parses the authenticationResponseJson of Credential Manager, or returns null when it lacks a required field.
        fun parse(text: String): BridgePublicKeyCredential? {
            val json = try {
                Json.parseToJsonElement(text)
            } catch (e: SerializationException) {
                return null
            } as? JsonObject ?: return null
            val response = json["response"] as? JsonObject ?: return null
            return BridgePublicKeyCredential(
                id = json.string("id") ?: return null,
                rawId = json.string("rawId") ?: return null,
                authenticatorAttachment = json.string("authenticatorAttachment"),
                response = Response(
                    clientDataJSON = response.string("clientDataJSON") ?: return null,
                    authenticatorData = response.string("authenticatorData") ?: return null,
                    signature = response.string("signature") ?: return null,
                    userHandle = response.string("userHandle"),
                ),
                clientExtensionResults = json["clientExtensionResults"] as? JsonObject ?: JsonObject(emptyMap()),
            )
        }

        private fun JsonObject.string(key: String): String? =
            (this[key] as? JsonPrimitive)?.takeIf { it.isString }?.content
    }
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

// True when rpId is host or a parent domain of host, compared without case,
// as a browser checks the rpId of a WebAuthn request against the page's origin.
internal fun isRpIdAllowed(rpId: String, host: String): Boolean {
    if (rpId.isEmpty()) {
        return false
    }
    val r = rpId.lowercase(Locale.ROOT)
    val h = host.lowercase(Locale.ROOT)
    return h == r || h.endsWith(".$r")
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

internal fun capabilitiesReply(id: String): BridgeReply {
    return BridgeReply(id, BridgeStatus.OK, capabilities = BRIDGE_CAPABILITIES)
}
