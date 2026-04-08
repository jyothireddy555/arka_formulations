package com.arkaformulations.arka_formulations

import android.content.Context
import android.location.LocationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.arkaformulations/mock_location"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "isMockLocation") {
                    result.success(isMockLocationEnabled())
                } else {
                    result.notImplemented()
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