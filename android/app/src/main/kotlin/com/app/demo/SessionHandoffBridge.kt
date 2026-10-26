package com.app.demo

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Shared sign-in between the fleet's own apps on one phone (Ray: "its one
 * device and same account so i expect them to use same token").
 *
 * Transport only, both directions. The Dart half is base_sdk's
 * SessionHandoff; what goes in the hand-off (a one-time server code, or the
 * local account record when the backend cannot be reached) is auth_sdk's
 * business, and this class passes it through as opaque strings.
 *
 * WHO MAY TALK. Only apps signed with the same key:
 *
 *  - Receiving: the only door in is [SessionHandoffActivity], declared with
 *    android:permission="[PERMISSION]", a permission every fleet app defines
 *    with protectionLevel="signature" (base_sdk's AndroidManifest.xml). The
 *    system refuses to start it for any app not signed with the same key,
 *    so another app cannot forge a hand-off. Extras that reach MainActivity
 *    any other way are never read.
 *  - Sending: [openWithHandoff] checks the target is signed with this app's
 *    key (PackageManager.checkSignatures) and addresses its
 *    SessionHandoffActivity by explicit component, so nothing else can
 *    receive it.
 *
 * The hand-off itself lives only in this process's memory, for
 * [PENDING_TTL_MS], and is cleared the first time Dart reads it.
 */
object SessionHandoffBridge {

    const val CHANNEL = "rokct.base_sdk/session_handoff"

    /** The signature-level permission guarding [SessionHandoffActivity]. */
    const val PERMISSION = "rokct.permission.SESSION_HANDOFF"

    /** The action [SessionHandoffActivity] answers. */
    const val ACTION = "rokct.intent.action.SESSION_HANDOFF"

    const val EXTRA_CODE = "rokct.handoff.code"
    const val EXTRA_ACCOUNT = "rokct.handoff.account"
    const val EXTRA_SOURCE = "rokct.handoff.source"

    /** A hand-off older than this is dropped unread. */
    private const val PENDING_TTL_MS = 2 * 60 * 1000L

    @Volatile
    private var pending: Map<String, String>? = null

    @Volatile
    private var pendingAt: Long = 0L

    @Volatile
    private var channel: MethodChannel? = null

    fun register(messenger: BinaryMessenger, activity: Activity) {
        val methodChannel = MethodChannel(messenger, CHANNEL)
        channel = methodChannel
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ownPackage" -> result.success(activity.packageName)
                "takePending" -> result.success(takePending())
                "canHandOff" -> result.success(
                    handOffTarget(activity, call.argument<String>("package")) != null,
                )
                "openWithHandoff" -> result.success(
                    openWithHandoff(
                        activity,
                        call.argument<String>("package"),
                        call.argument<String>("code"),
                        call.argument<String>("account"),
                    ),
                )
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Called by [SessionHandoffActivity] once the system has let a same-key
     * app in. Keeps the hand-off for Dart and tells a running engine.
     */
    fun deliver(code: String?, account: String?, source: String?) {
        val values = HashMap<String, String>()
        if (!code.isNullOrEmpty() && code.length <= 512) values["code"] = code
        if (!account.isNullOrEmpty() && account.length <= 16 * 1024) values["account"] = account
        if (values.isEmpty()) return
        if (!source.isNullOrEmpty()) values["source"] = source
        pending = values
        pendingAt = SystemClock.elapsedRealtime()
        Handler(Looper.getMainLooper()).post {
            try {
                channel?.invokeMethod("pendingChanged", null)
            } catch (e: Exception) {
                // No engine yet: Dart asks on its first frame instead.
            }
        }
    }

    private fun takePending(): Map<String, String>? {
        val values = pending
        val age = SystemClock.elapsedRealtime() - pendingAt
        pending = null
        if (values == null || age > PENDING_TTL_MS) return null
        return values
    }

    /**
     * [packageName]'s SessionHandoffActivity when that app is signed with
     * this app's key, else null.
     */
    private fun handOffTarget(activity: Activity, packageName: String?): ComponentName? {
        if (packageName.isNullOrEmpty() || packageName == activity.packageName) return null
        return try {
            val packageManager = activity.packageManager
            if (packageManager.checkSignatures(activity.packageName, packageName) !=
                PackageManager.SIGNATURE_MATCH
            ) {
                return null
            }
            val info = packageManager
                .queryIntentActivities(Intent(ACTION).setPackage(packageName), 0)
                .firstOrNull()
                ?.activityInfo
                ?: return null
            ComponentName(info.packageName, info.name)
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Open [packageName] through its SessionHandoffActivity carrying the
     * hand-off. False when the app is not a same-key fleet app, carries no
     * entry, or the system refused the start (for example this app does not
     * hold [PERMISSION]); the caller then opens the app the ordinary way.
     */
    private fun openWithHandoff(
        activity: Activity,
        packageName: String?,
        code: String?,
        account: String?,
    ): Boolean {
        if (code.isNullOrEmpty() && account.isNullOrEmpty()) return false
        val target = handOffTarget(activity, packageName) ?: return false
        return try {
            val open = Intent(ACTION)
                .setComponent(target)
                .putExtra(EXTRA_SOURCE, activity.packageName)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (!code.isNullOrEmpty()) open.putExtra(EXTRA_CODE, code)
            if (!account.isNullOrEmpty()) open.putExtra(EXTRA_ACCOUNT, account)
            activity.startActivity(open)
            true
        } catch (e: Exception) {
            false
        }
    }
}
