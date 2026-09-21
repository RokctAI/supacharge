package com.app.demo

import android.app.Activity
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CreateCredentialResponse
import androidx.credentials.CreateRestoreCredentialRequest
import androidx.credentials.CreateRestoreCredentialResponse
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.GetRestoreCredentialOption
import androidx.credentials.RestoreCredential
import androidx.credentials.exceptions.ClearCredentialException
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.CreateCredentialProviderConfigurationException
import androidx.credentials.exceptions.CreateCredentialUnsupportedException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.GetCredentialProviderConfigurationException
import androidx.credentials.exceptions.GetCredentialUnsupportedException
import androidx.credentials.exceptions.NoCredentialException
import androidx.credentials.exceptions.restorecredential.E2eeUnavailableException
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

/**
 * Platform plumbing for Android's Restore Credentials API (Zero-Tap Sign-In),
 * required by Play from April 2027.
 *
 * Transport only: this class never decides when a restore key is created,
 * retrieved or deleted, and never speaks to the relying party. The auth SDK
 * owns the flow and passes the WebAuthn JSON through as opaque strings. The
 * Dart half is base_sdk's RestoreCredentialService.
 *
 * Uses the callback (`...Async`) arm of CredentialManager rather than its
 * suspend functions, so the app does not have to take a kotlinx-coroutines
 * dependency it does not otherwise need.
 */
object RestoreCredentialBridge {

    const val CHANNEL = "rokct.base_sdk/restore_credentials"

    /**
     * Restore Credentials needs Android 9. The fleet ships minSdk 24, so this
     * is a real runtime gate, not a formality.
     */
    private const val MIN_SDK = Build.VERSION_CODES.P

    /**
     * Its own preferences file, deliberately not the Flutter one: the flag is
     * written by the backup agent process, which has no Flutter engine.
     */
    private const val RESTORE_PREFS = "rokct_restore_credentials"
    private const val KEY_RESTORE_PENDING = "restore_finished_pending"

    private val mainExecutor: Executor = Executor { command ->
        Handler(Looper.getMainLooper()).post(command)
    }

    fun register(messenger: BinaryMessenger, activity: Activity) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            handle(call, result, activity)
        }
    }

    /**
     * Called from the backup agent once a system restore has completed.
     * BackupAgent.onRestoreFinished is the correct hook: onRestore fires only
     * for key-value backups, while onRestoreFinished fires for any restore.
     */
    fun markRestoreFinished(context: Context) {
        context.getSharedPreferences(RESTORE_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_RESTORE_PENDING, true)
            .apply()
    }

    private fun consumeRestoreSignal(context: Context): Boolean {
        val prefs = context.getSharedPreferences(RESTORE_PREFS, Context.MODE_PRIVATE)
        val pending = prefs.getBoolean(KEY_RESTORE_PENDING, false)
        if (pending) {
            prefs.edit().remove(KEY_RESTORE_PENDING).apply()
        }
        return pending
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
        when (call.method) {
            "isSupported" -> result.success(Build.VERSION.SDK_INT >= MIN_SDK)

            "consumeRestoreSignal" -> result.success(consumeRestoreSignal(activity))

            "create" -> {
                if (!supported(result)) return
                val requestJson = call.argument<String>("requestJson")
                if (requestJson.isNullOrEmpty()) {
                    result.success(error("requestJson is required"))
                    return
                }
                val cloudBackup = call.argument<Boolean>("isCloudBackupEnabled") ?: true
                create(activity, requestJson, cloudBackup, allowRetry = cloudBackup, result)
            }

            "retrieve" -> {
                if (!supported(result)) return
                val requestJson = call.argument<String>("requestJson")
                if (requestJson.isNullOrEmpty()) {
                    result.success(error("requestJson is required"))
                    return
                }
                retrieve(activity, requestJson, result)
            }

            "clear" -> {
                if (!supported(result)) return
                clear(activity, result)
            }

            else -> result.notImplemented()
        }
    }

    private fun supported(result: MethodChannel.Result): Boolean {
        if (Build.VERSION.SDK_INT >= MIN_SDK) return true
        result.success(
            payload(
                "unsupported",
                message = "Restore Credentials needs Android 9 or newer.",
            )
        )
        return false
    }

    private fun create(
        activity: Activity,
        requestJson: String,
        isCloudBackupEnabled: Boolean,
        allowRetry: Boolean,
        result: MethodChannel.Result,
    ) {
        val request = CreateRestoreCredentialRequest(requestJson, isCloudBackupEnabled)
        CredentialManager.create(activity).createCredentialAsync(
            activity,
            request,
            null,
            mainExecutor,
            object : CredentialManagerCallback<CreateCredentialResponse, CreateCredentialException> {
                override fun onResult(response: CreateCredentialResponse) {
                    val json = (response as? CreateRestoreCredentialResponse)?.responseJson
                    result.success(
                        payload(
                            "success",
                            responseJson = json,
                            cloudBackupEnabled = isCloudBackupEnabled,
                        )
                    )
                }

                override fun onError(e: CreateCredentialException) {
                    // The one retry Google's guidance prescribes: the user has
                    // no backup, no screen lock, or no end-to-end encryption,
                    // so the key can only be stored locally. Retried here so
                    // callers never have to know about it; the result reports
                    // which setting actually stuck.
                    if (e is E2eeUnavailableException && allowRetry) {
                        create(activity, requestJson, false, allowRetry = false, result)
                        return
                    }
                    result.success(createFailure(e))
                }
            },
        )
    }

    private fun retrieve(activity: Activity, requestJson: String, result: MethodChannel.Result) {
        val request = GetCredentialRequest(listOf(GetRestoreCredentialOption(requestJson)))
        CredentialManager.create(activity).getCredentialAsync(
            activity,
            request,
            null,
            mainExecutor,
            object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                override fun onResult(response: GetCredentialResponse) {
                    val credential = response.credential
                    if (credential !is RestoreCredential) {
                        result.success(
                            error("Expected a RestoreCredential, got ${credential.type}")
                        )
                        return
                    }
                    result.success(
                        payload("success", responseJson = credential.authenticationResponseJson)
                    )
                }

                override fun onError(e: GetCredentialException) {
                    result.success(getFailure(e))
                }
            },
        )
    }

    private fun clear(activity: Activity, result: MethodChannel.Result) {
        val request = ClearCredentialStateRequest(
            ClearCredentialStateRequest.TYPE_CLEAR_RESTORE_CREDENTIAL
        )
        CredentialManager.create(activity).clearCredentialStateAsync(
            request,
            null,
            mainExecutor,
            object : CredentialManagerCallback<Void?, ClearCredentialException> {
                override fun onResult(response: Void?) {
                    result.success(payload("success"))
                }

                override fun onError(e: ClearCredentialException) {
                    result.success(error(e.message ?: e.type))
                }
            },
        )
    }

    private fun createFailure(e: CreateCredentialException): Map<String, Any?> = when (e) {
        is CreateCredentialCancellationException -> payload("cancelled", message = e.message)
        is E2eeUnavailableException,
        is CreateCredentialUnsupportedException,
        is CreateCredentialProviderConfigurationException,
        -> payload("unavailable", message = e.message ?: e.type)
        else -> error(e.message ?: e.type)
    }

    private fun getFailure(e: GetCredentialException): Map<String, Any?> = when (e) {
        is GetCredentialCancellationException -> payload("cancelled", message = e.message)
        is NoCredentialException -> payload("noCredential", message = e.message)
        is GetCredentialUnsupportedException,
        is GetCredentialProviderConfigurationException,
        -> payload("unavailable", message = e.message ?: e.type)
        else -> error(e.message ?: e.type)
    }

    private fun error(message: String?): Map<String, Any?> = payload("error", message = message)

    private fun payload(
        status: String,
        responseJson: String? = null,
        message: String? = null,
        cloudBackupEnabled: Boolean? = null,
    ): Map<String, Any?> = mapOf(
        "status" to status,
        "responseJson" to responseJson,
        "message" to message,
        "cloudBackupEnabled" to cloudBackupEnabled,
    )
}
