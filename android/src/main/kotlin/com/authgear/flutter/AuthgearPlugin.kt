package com.authgear.flutter

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.net.Uri
import android.os.Build
import android.provider.Settings
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
      "getDeviceInfo" -> {
        this.getDeviceInfo(result)
      }
      else -> result.notImplemented()
    }
  }

  private fun getDeviceInfo(result: Result) {
    var baseOS = ""
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      if (Build.VERSION.BASE_OS != null) {
        baseOS = Build.VERSION.BASE_OS
      }
    }

    var previewSDKInt = ""
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      previewSDKInt = Build.VERSION.PREVIEW_SDK_INT.toString()
    }

    var releaseOrCodename = ""
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      if (Build.VERSION.RELEASE_OR_CODENAME != null) {
        releaseOrCodename = Build.VERSION.RELEASE_OR_CODENAME
      }
    }

    var securityPatch = ""
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      if (Build.VERSION.SECURITY_PATCH != null) {
        securityPatch = Build.VERSION.SECURITY_PATCH
      }
    }

    val buildVersionMap = hashMapOf<String, String>(
      "BASE_OS" to baseOS,
      "CODENAME" to Build.VERSION.CODENAME,
      "INCREMENTAL" to Build.VERSION.INCREMENTAL,
      "PREVIEW_SDK_INT" to previewSDKInt,
      "RELEASE" to Build.VERSION.RELEASE,
      "RELEASE_OR_CODENAME" to releaseOrCodename,
      "SDK" to Build.VERSION.SDK,
      "SDK_INT" to Build.VERSION.SDK_INT.toString(),
      "SECURITY_PATCH" to securityPatch,
    )

    val buildMap = hashMapOf(
      "BOARD" to Build.BOARD,
      "BRAND" to Build.BRAND,
      "MODEL" to Build.MODEL,
      "DEVICE" to Build.DEVICE,
      "DISPLAY" to Build.DISPLAY,
      "HARDWARE" to Build.HARDWARE,
      "MANUFACTURER" to Build.MANUFACTURER,
      "PRODUCT" to Build.PRODUCT,
      "VERSION" to buildVersionMap
    )

    val context = pluginBinding?.applicationContext!!

    val packageName = context.getPackageName()
    val packageInfo: PackageInfo = try {
      context.packageManager.getPackageInfo(packageName, 0)
    } catch (e: Exception) {
      result.exception(e)
      return
    }
    val versionCode = packageInfo.versionCode.toString()
    val versionName = packageInfo.versionName
    var longVersionCode = ""
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      longVersionCode = packageInfo.longVersionCode.toString()
    }
    val packageInfoMap = hashMapOf(
      "packageName" to packageName,
      "versionName" to versionName,
      "versionCode" to versionCode,
      "longVersionCode" to longVersionCode,
    )

    val contentResolver = context.contentResolver
    var bluetoothName: String = Settings.Secure.getString(contentResolver, "bluetooth_name")
    if (bluetoothName == null) {
      bluetoothName = ""
    }
    var deviceName = ""
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
      deviceName = Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME)
      if (deviceName == null) {
        deviceName = ""
      }
    }
    var androidID: String = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
    if (androidID == null) {
      androidID = ""
    }
    val settingsMap = hashMapOf(
      "Secure" to hashMapOf(
        "bluetooth_name" to bluetoothName,
        "ANDROID_ID" to androidID,
      ),
      "Global" to hashMapOf(
        "DEVICE_NAME" to deviceName,
      ),
    )

    var applicationInfoLabel = context.applicationInfo.loadLabel(context.packageManager)
    if (applicationInfoLabel == null) {
      applicationInfoLabel = ""
    }

    val root = hashMapOf(
      "android" to hashMapOf(
        "Build" to buildMap,
        "PackageInfo" to packageInfoMap,
        "Settings" to settingsMap,
        "ApplicationInfoLabel" to applicationInfoLabel.toString(),
      )
    )

    result.success(root)
  }
}

internal fun Result.noActivity() {
  this.error("NO_ACTIVITY", "no activity", null)
}

internal fun Result.cancel() {
  this.error("CANCEL", "cancel", null)
}

internal fun Result.exception(e: Exception) {
  this.error(e.javaClass.name, e.message, e)
}
