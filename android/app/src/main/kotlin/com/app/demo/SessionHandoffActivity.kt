package com.app.demo

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * The one door a shared sign-in comes in through (see SessionHandoffBridge).
 *
 * Declared in AndroidManifest.xml with
 * android:permission="rokct.permission.SESSION_HANDOFF", a signature-level
 * permission, so the system starts it only for apps signed with this app's
 * key. It shows nothing: it hands the extras to the bridge, opens the app
 * the way its launcher icon does (an app already running comes to the
 * front as it was), and finishes.
 */
class SessionHandoffActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Only a fresh start carries a hand-off; a re-creation must not
        // deliver the same one twice.
        if (savedInstanceState == null) {
            try {
                SessionHandoffBridge.deliver(
                    intent?.getStringExtra(SessionHandoffBridge.EXTRA_CODE),
                    intent?.getStringExtra(SessionHandoffBridge.EXTRA_ACCOUNT),
                    intent?.getStringExtra(SessionHandoffBridge.EXTRA_SOURCE),
                )
            } catch (e: Exception) {
                // A malformed hand-off is simply not one; the app still opens.
            }
        }
        try {
            val launch = packageManager.getLaunchIntentForPackage(packageName)
            if (launch != null) {
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(launch)
            }
        } catch (e: Exception) {
            // Nothing to open is still not worth a crash.
        }
        finish()
    }
}
