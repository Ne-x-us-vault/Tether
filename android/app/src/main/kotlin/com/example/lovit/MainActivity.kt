// ══════════════════════════════════════════════════════════════════════════════
// MainActivity.kt — Lovit App
//
// File location:
//   android/app/src/main/kotlin/<your_package_name>/MainActivity.kt
//
// Replace <your_package_name> with your actual package.
// To find it: open android/app/build.gradle and look for applicationId.
// Example: if applicationId = "com.example.lovit"
//   → file lives at android/app/src/main/kotlin/com/example/lovit/MainActivity.kt
// ══════════════════════════════════════════════════════════════════════════════

package com.example.lovit   // ← change this to match your applicationId

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "lovit/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                // Opens Android's Usage Access settings page so the user can
                // manually grant PACKAGE_USAGE_STATS for Lovit.
                "openUsageSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    )
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}