package com.app.demo

import android.app.Activity
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import java.lang.reflect.Modifier

class MainActivity: FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // Physical RAM lookup for base_sdk's MemoryPressureService.
        DeviceMemoryBridge.register(messenger, applicationContext)
        // Restore Credentials (Zero-Tap Sign-In) plumbing. Needs an Activity,
        // not the application context: the credential provider shows system UI.
        RestoreCredentialBridge.register(messenger, this)
        // Bridges that only exist when the app is composed with the SDK that
        // ships them. This activity cannot reference them directly: it is
        // base_sdk's template and must still compile in an app composed
        // without them.
        registerOptionalBridges(messenger)
    }

    /**
     * Registers every bridge in [OPTIONAL_BRIDGES] that is actually present in
     * this build.
     *
     * A package SDK (as opposed to a Flutter plugin) has no registration hook
     * of its own: its Kotlin lands in the host's source tree through the
     * composer's `installs` and then needs someone to call it. Only the host
     * Activity can do that, and only reflectively - a direct reference would
     * fail to compile in every app composed without that SDK.
     *
     * The package is read from this class at runtime rather than hard-coded:
     * the release lane rewrites every Kotlin source's `package` declaration to
     * the customer's application package before it compiles, so a literal
     * "com.app.demo.X" would resolve to nothing in a shipped build. Bridges
     * are installed next to this activity, so its own package is the right
     * one to look in.
     */
    private fun registerOptionalBridges(messenger: BinaryMessenger) {
        val packageName = javaClass.`package`?.name ?: return
        for (bridgeName in OPTIONAL_BRIDGES) {
            try {
                val bridge = Class.forName("$packageName.$bridgeName")
                val register = bridge.getMethod(
                    "register",
                    BinaryMessenger::class.java,
                    Activity::class.java,
                )
                // A Kotlin `object` exposes its members on the INSTANCE
                // singleton unless they are annotated @JvmStatic, so accept
                // either shape instead of dictating one to the SDKs.
                val receiver = if (Modifier.isStatic(register.modifiers)) {
                    null
                } else {
                    bridge.getField("INSTANCE").get(null)
                }
                register.invoke(receiver, messenger, this)
            } catch (e: ClassNotFoundException) {
                // App composed without the SDK that ships this bridge - nothing to register.
            } catch (e: ReflectiveOperationException) {
                // Present but not callable: a real defect in that bridge, and
                // still not worth taking the app down on the launch path.
                Log.e(TAG, "Optional bridge $bridgeName could not be registered", e)
            }
        }
    }

    private companion object {
        private const val TAG = "MainActivity"

        /**
         * Simple class names, each expected to expose
         * `register(BinaryMessenger, Activity)` and to be installed into this
         * activity's own package by its SDK's manifest `installs`.
         *
         * - DefaultHomeBridge (launch_sdk): the default-launcher role ask
         *   behind the `rokct.launch_sdk/default_home` channel.
         * - AppChangesBridge (launch_sdk): install and uninstall events
         *   behind the `rokct.launch_sdk/app_changes` channel, so the
         *   launcher is told when its app list changes instead of asking.
         */
        private val OPTIONAL_BRIDGES = listOf("DefaultHomeBridge", "AppChangesBridge")
    }
}
