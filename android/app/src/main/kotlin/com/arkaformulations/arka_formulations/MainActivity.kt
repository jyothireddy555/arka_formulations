package com.arkaformulations.arka_formulations

import android.content.Context
import android.location.LocationManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL        = "com.arkaformulations/mock_location"
    private val SECURE_CHANNEL = "com.arkaformulations/screen_secure"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Mock-location channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "isMockLocation") {
                    result.success(isMockLocationEnabled())
                } else {
                    result.notImplemented()
                }
            }

        // ── Screenshot / screen-recording block channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableSecure" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "disableSecure" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isMockLocationEnabled(): Boolean {
        return try {
            val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val providers = listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER
            )
            providers.any { provider ->
                try {
                    lm.isProviderEnabled(provider) &&
                            lm.getLastKnownLocation(provider)?.isFromMockProvider == true
                } catch (e: SecurityException) {
                    false
                }
            }
        } catch (e: Exception) {
            false
        }
    }
}