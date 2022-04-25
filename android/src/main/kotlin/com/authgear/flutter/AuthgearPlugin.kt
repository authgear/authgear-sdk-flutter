package com.authgear.flutter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

class AuthgearPlugin: FlutterPlugin, ActivityAware, MethodCallHandler, PluginRegistry.ActivityResultListener {
  private lateinit var channel: MethodChannel
  private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
  private var activityBinding: ActivityPluginBinding? = null
  private val startActivityHandles = StartActivityHandles()

  companion object {
    val TAG_AUTHENTICATION = 1
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_authgear")
    channel.setMethodCallHandler(this)
    pluginBinding = flutterPluginBinding
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    pluginBinding = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBinding = binding
    activityBinding?.addActivityResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activityBinding = null
    activityBinding?.removeActivityResultListener(this)
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activityBinding = binding
    activityBinding?.addActivityResultListener(this)
  }

  override fun onDetachedFromActivity() {
    activityBinding = null
    activityBinding?.removeActivityResultListener(this)
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    val handle = startActivityHandles.pop(requestCode)
    if (handle == null) {
      return false
    }

    return when (handle.tag) {
      TAG_AUTHENTICATION -> {
        when (resultCode) {
          Activity.RESULT_CANCELED -> handle.result.cancel()
          Activity.RESULT_OK -> handle.result.success(data?.data.toString())
        }
        true
      }
      else -> false
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "authenticate" -> {
        val url = Uri.parse(call.argument("url"))
        val redirectURI = Uri.parse(call.argument("redirectURI"))
        // Custom tabs do not support incognito mode for now.
//        val preferEphemeral: Boolean = call.argument("preferEphemeral")!!
        val requestCode = startActivityHandles.push(StartActivityHandle(TAG_AUTHENTICATION, result))
        val activity = activityBinding?.activity
        if (activity == null) {
          result.noActivity()
          return
        }
        OAuthRedirectActivity.registerRedirectURI(redirectURI)
        val intent = OAuthCoordinatorActivity.createAuthorizationIntent(activity, url)
        activity.startActivityForResult(intent, requestCode)
      }
      else -> result.notImplemented()
    }
  }
}

internal fun Result.noActivity() {
  this.error("NO_ACTIVITY", "no activity", null)
}

internal fun Result.cancel() {
  this.error("CANCEL", "cancel", null)
}
