package com.dishaanhitech.erp_mobile

import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Only while an incoming call is ringing: show over the lock screen and
        // wake the screen, like a phone call. Switched off again right after,
        // so the ERP is never visible on a locked phone otherwise.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "erp/call_screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ringing" -> { setRinging(call.arguments == true); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setRinging(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }
}
