package com.authgear.flutter

import java.security.MessageDigest
import org.json.JSONObject

internal fun Map<String, Any>.toSHA256Thumbprint(): String {
    val p = mutableMapOf<Any?, Any?>()
    when (this["kty"]) {
        "RSA" -> {
            // required members for an RSA public key are e, kty, n
            // in lexicographic order
            p["e"] = this["e"]
            p["kty"] = this["kty"]
            p["n"] = this["n"]
        }
        else -> {
            throw NotImplementedError("unknown kty")
        }
    }
    val jsonBytes = JSONObject(p).toString().toByteArray()
    val digest: MessageDigest = MessageDigest.getInstance("SHA-256")
    val hashBytes = digest.digest(jsonBytes)

    return hashBytes.base64URLEncode()
}