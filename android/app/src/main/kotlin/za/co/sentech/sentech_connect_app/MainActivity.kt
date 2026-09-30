package za.co.sentech.sentech_connect_app

import android.os.SystemClock
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity): local_auth's BiometricPrompt
// needs a FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // FLAG_SECURE blocks screenshots, screen recording and the
                    // recent-apps thumbnail while a sensitive screen (RICA,
                    // account) is showing.
                    "setSecure" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    // Milliseconds since boot incl. deep sleep; unaffected by the
                    // user changing the wall clock. Used to make the free-WiFi
                    // cap/expiry harder to cheat client-side.
                    "elapsedRealtimeMs" -> result.success(SystemClock.elapsedRealtime())
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val CHANNEL = "za.co.sentech.sentech_connect_app/platform"
    }
}
