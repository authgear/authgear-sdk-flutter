package com.authgear.flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageInfo
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.biometric.BiometricManager
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.util.*
import kotlin.collections.ArrayList
import kotlin.collections.HashMap


class AuthgearPlugin: FlutterPlugin, ActivityAware, MethodCallHandler, PluginRegistry.ActivityResultListener {
  private lateinit var channel: MethodChannel
  private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
  private var activityBinding: ActivityPluginBinding? = null
  private val startActivityHandles = StartActivityHandles()

  companion object {
    private const val TAG_AUTHENTICATION = 1
    private const val TAG_OPEN_URL = 2
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
      TAG_OPEN_URL -> {
        when (resultCode) {
          Activity.RESULT_CANCELED -> handle.result.success(null)
          Activity.RESULT_OK -> handle.result.success(null)
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
      "openURL" -> {
        val url = Uri.parse(call.argument("url"))
        val requestCode = startActivityHandles.push(StartActivityHandle(TAG_OPEN_URL, result))
        val activity = activityBinding?.activity
        if (activity == null) {
          result.noActivity()
          return
        }
        val intent = WebViewActivity.createIntent(activity, url)
        activity.startActivityForResult(intent, requestCode)
      }
      "getDeviceInfo" -> {
        this.getDeviceInfo(result)
      }
      "storageSetItem" -> {
        val key: String = call.argument("key")!!
        val value: String = call.argument("value")!!
        this.storageSetItem(key, value, result)
      }
      "storageGetItem" -> {
        val key: String = call.argument("key")!!
        this.storageGetItem(key, result)
      }
      "storageDeleteItem" -> {
        val key: String = call.argument("key")!!
        this.storageDeleteItem(key, result)
      }
      "generateUUID" -> {
        this.generateUUID(result)
      }
      "checkBiometricSupported" -> {
        val android = call.argument<HashMap<String, Any>>("android")!!
        val constraint = android["constraint"] as ArrayList<String>
        val flags = constraintToFlag(constraint)
        this.checkBiometricSupported(flags, result)
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

  private fun getSharePreferences(): SharedPreferences {
    val context = pluginBinding?.applicationContext!!
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      val masterKey = MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
      return EncryptedSharedPreferences.create(
        context,
        "authgear_encrypted_shared_preferences",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
      )
    }
    return context.getSharedPreferences("authgear_shared_preferences", Context.MODE_PRIVATE)
  }

  private fun storageSetItem(key: String, value: String, result: Result) {
    try {
      val sharedPreferences = this.getSharePreferences()
      sharedPreferences.edit().putString(key, value).commit()
      result.success(null)
    } catch (e: Exception) {
      result.exception(e)
    }
  }

  private fun storageGetItem(key: String, result: Result) {
    try {
      val sharedPreferences = this.getSharePreferences()
      val value = sharedPreferences.getString(key, null)
      result.success(value)
    } catch (e: Exception) {
      result.exception(e)
    }
  }

  private fun storageDeleteItem(key: String, result: Result) {
    try {
      val sharedPreferences = this.getSharePreferences()
      sharedPreferences.edit().remove(key).commit()
      result.success(null)
    } catch (e: Exception) {
      result.exception(e)
    }
  }

  private fun generateUUID(result: Result) {
    val uuid = UUID.randomUUID().toString()
    result.success(uuid)
  }

  private fun constraintToFlag(constraint: ArrayList<String>): Int {
    var flag = 0
    for (c in constraint) {
      when (c) {
        "BIOMETRIC_STRONG" -> {
          flag = flag or BiometricManager.Authenticators.BIOMETRIC_STRONG
        }
        "DEVICE_CREDENTIAL" -> {
          flag = flag or BiometricManager.Authenticators.DEVICE_CREDENTIAL
        }
      }
    }
    return flag
  }

  private fun resultToString(result: Int): String {
    return when (result) {
      BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "BIOMETRIC_ERROR_HW_UNAVAILABLE"
      BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "BIOMETRIC_ERROR_NONE_ENROLLED"
      BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "BIOMETRIC_ERROR_NO_HARDWARE"
      BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED -> "BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED"
      BiometricManager.BIOMETRIC_ERROR_UNSUPPORTED -> "BIOMETRIC_ERROR_UNSUPPORTED"
      BiometricManager.BIOMETRIC_STATUS_UNKNOWN -> "BIOMETRIC_STATUS_UNKNOWN"
      else -> "BIOMETRIC_ERROR_UNKNOWN"
    }
  }

  private fun checkBiometricSupported(flag: Int, result: Result) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      result.biometricAPILevel()
      return
    }

    val manager = BiometricManager.from(pluginBinding?.applicationContext!!)
    val can = manager.canAuthenticate(flag)
    if (can == BiometricManager.BIOMETRIC_SUCCESS) {
      result.success(null)
      return
    }

    val resultString = resultToString(can)
    result.error(resultString, resultString, null)
  }
}

internal fun Result.noActivity() {
  this.error("NO_ACTIVITY", "no activity", null)
}

internal fun Result.cancel() {
  this.error("CANCEL", "cancel", null)
}

internal fun Result.biometricAPILevel() {
  this.error("DeviceAPILevelTooLow", "Biometric authentication requires at least API Level 23", null)
}

internal fun Result.exception(e: Exception) {
  this.error(e.javaClass.name, e.message, e)
}
