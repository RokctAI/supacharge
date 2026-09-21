package com.app.demo

import android.app.ActivityManager
import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Reports the device's physical RAM to Dart so base_sdk's
 * MemoryPressureService can size the image cache from it instead of running
 * Flutter's fixed 1000 images / 100MB on every device.
 *
 * ActivityManager.MemoryInfo.totalMem reports somewhat less than the nominal
 * figure a device is sold with - a "4GB" phone reports around 3.7GB - which
 * the Dart-side tier boundaries account for.
 */
object DeviceMemoryBridge {

    const val CHANNEL = "rokct.base_sdk/device_memory"

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "totalPhysicalMemoryBytes" -> {
                    val manager =
                        context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                    if (manager == null) {
                        result.success(null)
                    } else {
                        val info = ActivityManager.MemoryInfo()
                        manager.getMemoryInfo(info)
                        result.success(info.totalMem)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
