package com.authgear.flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageInfo
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.fragment.app.FragmentActivity
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.google.crypto.tink.shaded.protobuf.InvalidProtocolBufferException
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.security.*
import java.security.interfaces.RSAPublicKey
import java.util.*


class AuthgearPlugin: FlutterPlugin, ActivityAware, MethodCallHandler, PluginRegistry.ActivityResultListener {
  private lateinit var channel: MethodChannel
  private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
  private var activityBinding: ActivityPluginBinding? = null
  private val startActivityHandles = StartActivityHandles<Result>()

  companion object {
    private const val LOGTAG = "AuthgearPlugin"
    private const val ENCRYPTED_SHARED_PREFERENCES_NAME = "authgear_encrypted_shared_preferences"
    private const val TAG_AUTHENTICATION = 1
    private const val TAG_OPEN_URL = 2

    private val wechat: HashMap<String, MethodChannel> = hashMapOf()

    internal fun onWechatRedirectURI(uri: Uri): Boolean {
      val uriWithoutQuery = uri.buildUpon().clearQuery().fragment("").build().toString()
      val methodChannel = wechat.remove(uriWithoutQuery)
      if (methodChannel == null) {
        return false
      }
      methodChannel.invokeMethod("onWechatRedirectURI", uri.toString())
      return true
    }

    fun wechatErrorResult(errCode: Int, errStr: String, result: Result) {
      if (errCode == -2) {
        result.cancel()
      } else {
        result.error("WechatError", errStr, hashMapOf(
          "errCode" to errCode,
        ))
      }
    }
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
          Activity.RESULT_CANCELED -> handle.value.cancel()
          Activity.RESULT_OK -> handle.value.success(data?.data.toString())
        }
        true
      }
      TAG_OPEN_URL -> {
        when (resultCode) {
          Activity.RESULT_CANCELED -> handle.value.success(null)
          Activity.RESULT_OK -> handle.value.success(null)
        }
        true
      }
      else -> false
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "registerWechatRedirectURI" -> {
        this.storeWechat(call)
        result.success(null)
      }
      "openAuthorizeURL" -> {
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
      "openAuthorizeURLWithWebView" -> {
        val url = Uri.parse(call.argument("url"))
        val redirectURI = Uri.parse(call.argument("redirectURI"))
        val actionBarBackgroundColor = this.readColorInt(call, "actionBarBackgroundColor")
        val actionBarButtonTintColor = this.readColorInt(call, "actionBarButtonTintColor")
        val options = WebKitWebViewActivity.Options(url, redirectURI)
        options.actionBarBackgroundColor = actionBarBackgroundColor
        options.actionBarButtonTintColor = actionBarButtonTintColor

        val requestCode = startActivityHandles.push(StartActivityHandle(TAG_AUTHENTICATION, result))
        val activity = activityBinding?.activity
        if (activity == null) {
          result.noActivity()
          return
        }
        val intent = WebKitWebViewActivity.createIntent(activity, options)
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
        val android = call.argument<Map<String, Any>>("android")!!
        val constraint = android["constraint"] as ArrayList<String>
        val flags = constraintToFlag(constraint)
        this.checkBiometricSupported(flags, result)
      }
      "createBiometricPrivateKey" -> {
        val kid = call.argument<String>("kid")!!
        val payload = call.argument<Map<String, Any>>("payload")!!
        val android = call.argument<Map<String, Any>>("android")!!
        this.createBiometricPrivateKey(android, kid, payload, result)
      }
      "removeBiometricPrivateKey" -> {
        val kid = call.argument<String>("kid")!!
        this.removeBiometricPrivateKey(kid, result)
      }
      "signWithBiometricPrivateKey" -> {
        val kid = call.argument<String>("kid")!!
        val payload = call.argument<Map<String, Any>>("payload")!!
        val android = call.argument<Map<String, Any>>("android")!!
        this.signWithBiometricPrivateKey(android, kid, payload, result)
      }
      "createAnonymousPrivateKey" -> {
        val kid = call.argument<String>("kid")!!
        val payload = call.argument<Map<String, Any>>("payload")!!
        this.createAnonymousPrivateKey(kid, payload, result)
      }
      "removeAnonymousPrivateKey" -> {
        val kid = call.argument<String>("kid")!!
        this.removeAnonymousPrivateKey(kid, result)
      }
      "signWithAnonymousPrivateKey" -> {
        val kid = call.argument<String>("kid")!!
        val payload = call.argument<Map<String, Any>>("payload")!!
        this.signWithAnonymousPrivateKey(kid, payload, result)
      }
      else -> result.notImplemented()
    }
  }

  private fun storeWechat(call: MethodCall) {
    val wechatRedirectURI = call.argument<String>("wechatRedirectURI")
    val wechatMethodChannel = call.argument<String>("wechatMethodChannel")
    if (wechatRedirectURI == null || wechatMethodChannel == null) {
      return
    }
    val binaryMessenger = pluginBinding?.binaryMessenger
    if (binaryMessenger == null) {
      return
    }
    val channel = MethodChannel(binaryMessenger, wechatMethodChannel)
    wechat[wechatRedirectURI] = channel
  }

  private fun getDeviceInfo(result: Result) {
    var baseOS: String? = ""
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      if (Build.VERSION.BASE_OS != null) {
        baseOS = Build.VERSION.BASE_OS
      }
    }

    var previewSDKInt = ""
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      previewSDKInt = Build.VERSION.PREVIEW_SDK_INT.toString()
    }

    var releaseOrCodename: String? = ""
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      if (Build.VERSION.RELEASE_OR_CODENAME != null) {
        releaseOrCodename = Build.VERSION.RELEASE_OR_CODENAME
      }
    }

    var securityPatch: String? = ""
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      if (Build.VERSION.SECURITY_PATCH != null) {
        securityPatch = Build.VERSION.SECURITY_PATCH
      }
    }

    val buildVersionMap = hashMapOf(
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
    var bluetoothName: String? = ""
    if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.S) {
      bluetoothName = Settings.Secure.getString(contentResolver, "bluetooth_name")
      if (bluetoothName == null) {
        bluetoothName = ""
      }
    }
    var deviceName: String? = ""
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
      deviceName = Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME)
      if (deviceName == null) {
        deviceName = ""
      }
    }
    var androidID: String? = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
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

    var applicationInfoLabel: CharSequence? = context.applicationInfo.loadLabel(context.packageManager)
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

  private fun deleteSharedPreferences(context: Context, name: String) {
    // NOTE(backup): Explanation on the backup problem.
    // EncryptedSharedPreferences depends on a master key stored in AndroidKeyStore.
    // The master key is not backed up.
    // However, the EncryptedSharedPreferences is backed up.
    // When the app is re-installed, and restored from a backup.
    // A new master key is created, but it cannot decrypt the restored EncryptedSharedPreferences.
    // This problem is persistence until the EncryptedSharedPreferences is deleted.
    //
    // The official documentation of EncryptedSharedPreferences tell us to
    // exclude the EncryptedSharedPreferences from a backup.
    // But defining a backup rule is not very appropriate in a SDK.
    // So we try to fix this in our code instead.
    //
    // This fix is tested against security-crypto@1.1.0-alpha06 and tink-android@1.8.0
    // Upgrading to newer versions may result in the library throwing a different exception that we fail to catch,
    // making this fix buggy.
    //
    // To reproduce the problem, you have to follow the steps here https://developer.android.com/identity/data/testingbackup#TestingBackup
    // The example app has been configured to back up the EncryptedSharedPreferences and nothing else.
    // One reason is to reproduce the problem, and another reason is that some platform, some Flutter,
    // store large files in the data directory. That will prevent the backup from working.
    //
    // The fix is to observe what exception was thrown by the underlying library
    // when the problem was re-produced.
    // When we catch the exception, we delete the EncryptedSharedPreferences and re-create it.
    //
    // Some references on how other fixed the problem.
    // https://github.com/stytchauth/stytch-android/blob/0.23.0/0.1.0/sdk/src/main/java/com/stytch/sdk/common/EncryptionManager.kt#L50
    // https://github.com/tink-crypto/tink-java/issues/23
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      context.deleteSharedPreferences(name)
    } else {
      context.getSharedPreferences(name, Context.MODE_PRIVATE).edit().clear().apply()
      val dir = File(context.applicationInfo.dataDir, "shared_prefs")
      File(dir, "$name.xml").delete()
    }
  }

  private fun getSharePreferences(): SharedPreferences {
    val context = pluginBinding?.applicationContext!!
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      val masterKey = MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
      try {
        return EncryptedSharedPreferences.create(
          context,
          ENCRYPTED_SHARED_PREFERENCES_NAME,
          masterKey,
          EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
          EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
      } catch (e: InvalidProtocolBufferException) {
        // NOTE(backup): Please search NOTE(backup) to understand what is going on here.
        Log.w(LOGTAG, "try to recover from backup problem in EncryptedSharedPreferences.create: $e")
        deleteSharedPreferences(context, ENCRYPTED_SHARED_PREFERENCES_NAME)
        return getSharePreferences()
      } catch (e: GeneralSecurityException) {
        // NOTE(backup): Please search NOTE(backup) to understand what is going on here.
        Log.w(LOGTAG, "try to recover from backup problem in EncryptedSharedPreferences.create: $e")
        deleteSharedPreferences(context, ENCRYPTED_SHARED_PREFERENCES_NAME)
        return getSharePreferences()
      } catch (e: IOException) {
        // NOTE(backup): Please search NOTE(backup) to understand what is going on here.
        Log.w(LOGTAG, "try to recover from backup problem in EncryptedSharedPreferences.create: $e")
        deleteSharedPreferences(context, ENCRYPTED_SHARED_PREFERENCES_NAME)
        return getSharePreferences()
      }
    }
    return context.getSharedPreferences("authgear_shared_preferences", Context.MODE_PRIVATE)
  }

  private fun storageSetItem(key: String, value: String, result: Result) {
    try {
      val sharedPreferences = this.getSharePreferences()
      sharedPreferences.edit().putString(key, value).commit()
      result.success(null)
    } catch (e: Exception) {
      // NOTE(backup): Please search NOTE(backup) to understand what is going on here.
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
        if (e is GeneralSecurityException) {
          Log.w(LOGTAG, "try to recover from backup problem in storageSetItem: $e")
          val context = pluginBinding?.applicationContext!!
          deleteSharedPreferences(context, ENCRYPTED_SHARED_PREFERENCES_NAME)
          return storageSetItem(key, value, result)
        }
      }
      result.exception(e)
    }
  }

  private fun storageGetItem(key: String, result: Result) {
    try {
      val sharedPreferences = this.getSharePreferences()
      val value = sharedPreferences.getString(key, null)
      result.success(value)
    } catch (e: Exception) {
      // NOTE(backup): Please search NOTE(backup) to understand what is going on here.
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
        if (e is GeneralSecurityException) {
          Log.w(LOGTAG, "try to recover from backup problem in storageGetItem: $e")
          val context = pluginBinding?.applicationContext!!
          deleteSharedPreferences(context, ENCRYPTED_SHARED_PREFERENCES_NAME)
          return storageGetItem(key, result)
        }
      }
      result.exception(e)
    }
  }

  private fun storageDeleteItem(key: String, result: Result) {
    try {
      val sharedPreferences = this.getSharePreferences()
      sharedPreferences.edit().remove(key).commit()
      result.success(null)
    } catch (e: Exception) {
      // NOTE(backup): Please search NOTE(backup) to understand what is going on here.
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
        if (e is GeneralSecurityException) {
          Log.w(LOGTAG, "try to recover from backup problem in storageDeleteItem: $e")
          val context = pluginBinding?.applicationContext!!
          deleteSharedPreferences(context, ENCRYPTED_SHARED_PREFERENCES_NAME)
          return storageDeleteItem(key, result)
        }
      }
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

  private fun authenticatorTypesToKeyProperties(flags: Int): Int {
    var out = 0
    if ((flags and BiometricManager.Authenticators.BIOMETRIC_STRONG) != 0) {
      out = out or KeyProperties.AUTH_BIOMETRIC_STRONG
    }
    if ((flags and BiometricManager.Authenticators.DEVICE_CREDENTIAL) != 0) {
      out = out or KeyProperties.AUTH_DEVICE_CREDENTIAL
    }
    return out
  }

  private fun errorCodeToString(errorCode: Int): String {
    return when (errorCode) {
      BiometricPrompt.ERROR_CANCELED -> "ERROR_CANCELED"
      BiometricPrompt.ERROR_HW_NOT_PRESENT -> "ERROR_HW_NOT_PRESENT"
      BiometricPrompt.ERROR_HW_UNAVAILABLE -> "ERROR_HW_UNAVAILABLE"
      BiometricPrompt.ERROR_LOCKOUT -> "ERROR_LOCKOUT"
      BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "ERROR_LOCKOUT_PERMANENT"
      BiometricPrompt.ERROR_NEGATIVE_BUTTON -> "ERROR_NEGATIVE_BUTTON"
      BiometricPrompt.ERROR_NO_BIOMETRICS -> "ERROR_NO_BIOMETRICS"
      BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL -> "ERROR_NO_DEVICE_CREDENTIAL"
      BiometricPrompt.ERROR_NO_SPACE -> "ERROR_NO_SPACE"
      BiometricPrompt.ERROR_SECURITY_UPDATE_REQUIRED -> "ERROR_SECURITY_UPDATE_REQUIRED"
      BiometricPrompt.ERROR_TIMEOUT -> "ERROR_TIMEOUT"
      BiometricPrompt.ERROR_UNABLE_TO_PROCESS -> "ERROR_UNABLE_TO_PROCESS"
      BiometricPrompt.ERROR_USER_CANCELED -> "ERROR_USER_CANCELED"
      BiometricPrompt.ERROR_VENDOR -> "ERROR_VENDOR"
      else -> "ERROR_UNKNOWN"
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

  private fun createBiometricPrivateKey(android: Map<String, Any>, kid: String, payload: Map<String, Any>, result: Result) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      result.biometricAPILevel()
      return
    }

    val fragmentActivity = getFragmentActivity()
    if (fragmentActivity == null) {
      result.fragmentActivity()
      return
    }

    val constraint = android["constraint"] as ArrayList<String>
    val invalidatedByBiometricEnrollment = android["invalidatedByBiometricEnrollment"] as Boolean
    val flags = constraintToFlag(constraint)
    val alias = "com.authgear.keys.biometric." + kid
    val promptInfo = buildPromptInfo(android, flags)

    val spec = makeBiometricKeyPairSpec(alias, authenticatorTypesToKeyProperties(flags), invalidatedByBiometricEnrollment)

    try {
      val keyPair = createKeyPair(spec)
      signBiometricJWT(fragmentActivity, keyPair, kid, payload, promptInfo, result)
    } catch (e: Exception) {
      result.exception(e)
    }
  }

  private fun createAnonymousPrivateKey(kid: String, payload: Map<String, Any>, result: Result) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      result.anonymousAPILevel()
      return
    }

    val alias = "com.authgear.keys.anonymous.$kid"
    val spec = makeAnonymousKeyPairSpec(alias)
    try {
      val keyPair = createKeyPair(spec)
      signAnonymousJWT(keyPair, kid, payload, result)
    } catch (e: Exception) {
      result.exception(e)
    }
  }

  private fun removeBiometricPrivateKey(kid: String, result: Result) {
    val alias = "com.authgear.keys.biometric.$kid"
    removePrivateKey(alias, result)
  }

  private fun removeAnonymousPrivateKey(kid: String, result: Result) {
    val alias = "com.authgear.keys.anonymous.$kid"
    removePrivateKey(alias, result)
  }

  private fun removePrivateKey(alias: String, result: Result) {
    try {
      val keyStore = KeyStore.getInstance("AndroidKeyStore")
      keyStore.load(null)
      keyStore.deleteEntry(alias)
      result.success(null)
    } catch (e: Exception) {
      result.exception(e)
    }
  }

  private fun signWithBiometricPrivateKey(android: Map<String, Any>, kid: String, payload: Map<String, Any>, result: Result) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      result.biometricAPILevel()
      return
    }

    val fragmentActivity = getFragmentActivity()
    if (fragmentActivity == null) {
      result.fragmentActivity()
      return
    }

    val constraint = android["constraint"] as ArrayList<String>
    val flags = constraintToFlag(constraint)
    val alias = "com.authgear.keys.biometric." + kid
    val promptInfo = buildPromptInfo(android, flags)

    try {
      val keyPair = getKeyPair(alias)
      signBiometricJWT(fragmentActivity, keyPair, kid, payload, promptInfo, result)
    } catch (e: Exception) {
      result.exception(e)
    }
  }

  private fun signWithAnonymousPrivateKey(kid: String, payload: Map<String, Any>, result: Result) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      result.anonymousAPILevel()
      return
    }

    val alias = "com.authgear.keys.anonymous.$kid"
    try {
      val keyPair = getKeyPair(alias)
      signAnonymousJWT(keyPair, kid, payload, result)
    } catch (e: Exception) {
      result.exception(e)
    }
  }

  private fun getFragmentActivity(): FragmentActivity? {
    val fragmentActivity = activityBinding?.activity
    if (fragmentActivity is FragmentActivity) {
      return fragmentActivity
    }
    return null
  }

  @RequiresApi(Build.VERSION_CODES.M)
  private fun makeBiometricKeyPairSpec(alias: String, flags: Int, invalidatedByBiometricEnrollment: Boolean): KeyGenParameterSpec {
    val builder = KeyGenParameterSpec.Builder(
        alias,
      KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
    )
    builder.setKeySize(2048)
    builder.setDigests(KeyProperties.DIGEST_SHA256)
    builder.setSignaturePaddings(KeyProperties.SIGNATURE_PADDING_RSA_PKCS1)
    builder.setUserAuthenticationRequired(true)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      builder.setUserAuthenticationParameters(
        0,
        flags
      )
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      builder.setInvalidatedByBiometricEnrollment(invalidatedByBiometricEnrollment)
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      // Samsung Android 12 treats setUnlockedDeviceRequired in a different way.
      // If setUnlockedDeviceRequired is true, then the device must be unlocked
      // with the same level of security requirement.
      // Otherwise, UserNotAuthenticatedException will be thrown when a cryptographic operation is initialized.
      //
      // The steps to reproduce the bug
      //
      // - Restart the device
      // - Unlock the device with credentials
      // - Create a Signature with a PrivateKey with setUnlockedDeviceRequired(true)
      // - Call Signature.initSign, UserNotAuthenticatedException will be thrown.
      // builder.setUnlockedDeviceRequired(true)
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      // User confirmation is not needed because the BiometricPrompt itself is a kind of confirmation.
      // builder.setUserConfirmationRequired(true)
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      // User presence requires a physical button which is not our intended use case.
      // builder.setUserPresenceRequired(true)
    }

    return builder.build()
  }

  @RequiresApi(Build.VERSION_CODES.M)
  private fun makeAnonymousKeyPairSpec(alias: String): KeyGenParameterSpec {
    val builder = KeyGenParameterSpec.Builder(
      alias,
      KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
    )
    builder.setKeySize(2048)
    builder.setDigests(KeyProperties.DIGEST_SHA256)
    builder.setSignaturePaddings(KeyProperties.SIGNATURE_PADDING_RSA_PKCS1)

    return builder.build()
  }

  @RequiresApi(Build.VERSION_CODES.M)
  private fun getKeyPair(alias: String): KeyPair {
    val keyStore = KeyStore.getInstance("AndroidKeyStore")
    keyStore.load(null)
    val entry = keyStore.getEntry(alias, null)
    if (entry is KeyStore.PrivateKeyEntry) {
      val privateKeyEntry = entry as KeyStore.PrivateKeyEntry
      return KeyPair(privateKeyEntry.certificate.publicKey, privateKeyEntry.privateKey)
    }
    throw KeyPermanentlyInvalidatedException()
  }

  private fun buildPromptInfo(android: Map<String, Any>, flags: Int): BiometricPrompt.PromptInfo {
    val title = android["title"] as String
    val subtitle = android["subtitle"] as String
    val description = android["description"] as String
    val negativeButtonText = android["negativeButtonText"] as String

    val builder = BiometricPrompt.PromptInfo.Builder()
    builder.setTitle(title)
    builder.setSubtitle(subtitle)
    builder.setDescription(description)
    builder.setAllowedAuthenticators(flags)
    if ((flags and BiometricManager.Authenticators.DEVICE_CREDENTIAL) == 0) {
      builder.setNegativeButtonText(negativeButtonText)
    }
    return builder.build()
  }

  @RequiresApi(Build.VERSION_CODES.M)
  private fun createKeyPair(spec: KeyGenParameterSpec ): KeyPair {
    val keyPairGenerator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, "AndroidKeyStore")
    keyPairGenerator.initialize(spec)
    return keyPairGenerator.generateKeyPair()
  }

  private fun signBiometricJWT(
    activity: FragmentActivity,
    keyPair: KeyPair,
    kid: String,
    payload: Map<String, Any>,
    promptInfo: BiometricPrompt.PromptInfo,
    result: Result,
  ) {
    val jwk = getJWK(keyPair, kid)
    val header = makeBiometricJWTHeader(jwk)
    val lockedSignature = makeSignature(keyPair.private)
    val cryptoObject = BiometricPrompt.CryptoObject(lockedSignature)
    val prompt = BiometricPrompt(activity, object : BiometricPrompt.AuthenticationCallback() {
      override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
        result.authenticationError(this@AuthgearPlugin.errorCodeToString(errorCode), errString.toString())
      }

      override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
        val signature = authResult.cryptoObject?.signature!!
        try {
          val jwt = this@AuthgearPlugin.signJWT(signature, header, payload)
          result.success(jwt)
        } catch (e: Exception) {
          result.exception(e)
        }
      }

      override fun onAuthenticationFailed() {
        // This callback will be invoked EVERY time the recognition failed.
        // So while the prompt is still opened, this callback can be called repetitively.
        // Finally, either onAuthenticationError or onAuthenticationSucceeded will be called.
        // So this callback is not important to the developer.
      }
    })
    val handler = Handler(Looper.getMainLooper())
    handler.post {
      prompt.authenticate(promptInfo, cryptoObject)
    }
  }

  private fun signAnonymousJWT(keyPair: KeyPair, kid: String, payload: Map<String, Any>, result: Result) {
    val jwk = getJWK(keyPair, kid)
    val header = makeAnonymousJWTHeader(jwk)
    try {
      val signature = makeSignature(keyPair.private)
      val jwt = signJWT(signature, header, payload)
      result.success(jwt)
    } catch (e: Exception) {
      result.exception(e)
    }
  }

  private fun getJWK(keyPair: KeyPair, kid: String): Map<String, Any> {
    val publicKey = keyPair.public
    val rsaPublicKey = publicKey as RSAPublicKey
    val jwk = hashMapOf(
      "kid" to kid,
      "alg" to "RS256",
      "kty" to "RSA",
      "n" to rsaPublicKey.modulus.toByteArray().base64URLEncode(),
      "e" to rsaPublicKey.publicExponent.toByteArray().base64URLEncode(),
    )
    return jwk
  }

  private fun makeBiometricJWTHeader(jwk: Map<String, Any>): Map<String, Any> {
    return hashMapOf(
      "typ" to "vnd.authgear.biometric-request",
      "kid" to jwk["kid"]!!,
      "alg" to jwk["alg"]!!,
      "jwk" to jwk,
    )
  }

  private fun makeAnonymousJWTHeader(jwk: Map<String, Any>): Map<String, Any> {
    return hashMapOf(
      "typ" to "vnd.authgear.anonymous-request",
      "kid" to jwk["kid"]!!,
      "alg" to jwk["alg"]!!,
      "jwk" to jwk,
    )
  }

  private fun makeSignature(privateKey: PrivateKey): Signature {
    val signature = Signature.getInstance("SHA256withRSA")
    signature.initSign(privateKey)
    return signature
  }

  private fun signJWT(signature: Signature, header: Map<String, Any>, payload: Map<String, Any>): String {
    val headerJSON = JSONObject(header).toString()
    val payloadJSON = JSONObject(payload).toString()
    val headerString = headerJSON.toByteArray(Charsets.UTF_8).base64URLEncode()
    val payloadString = payloadJSON.toByteArray(Charsets.UTF_8).base64URLEncode()
    val strToSign = "$headerString.$payloadString"
    signature.update(strToSign.toByteArray(Charsets.UTF_8))
    val sig = signature.sign()
    return "$strToSign.${sig.base64URLEncode()}"
  }

  private fun readColorInt(call: MethodCall, key: String): Int? {
    val s: String? = call.argument<String?>(key)
    if (s != null) {
      val l = s.toLong(16)
      val a = (l shr 24 and 0xff).toInt()
      val r = (l shr 16 and 0xff).toInt()
      val g = (l shr 8 and 0xff).toInt()
      val b = (l and 0xff).toInt()
      return Color.argb(a, r, g, b)
    }
    return null
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

internal fun Result.anonymousAPILevel() {
  this.error("DeviceAPILevelTooLow", "Anonymous user requires at least API Level 23", null)
}

internal fun Result.fragmentActivity() {
  this.error("FragmentActivity", "Authgear SDK requires your MainActivity to be a subclass of FlutterFragmentActivity", null)
}

internal fun Result.authenticationError(errorCodeString: String, message: String) {
  this.error(errorCodeString, message, null)
}

internal fun Result.exception(e: Exception) {
  this.error(e.javaClass.name, e.message, e)
}

internal fun ByteArray.base64URLEncode(): String {
  return Base64.encodeToString(this, Base64.NO_WRAP or Base64.URL_SAFE or Base64.NO_PADDING)
}
