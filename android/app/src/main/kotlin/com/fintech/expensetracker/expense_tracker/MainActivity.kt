package com.fintech.expensetracker.expense_tracker

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.fintech.expensetracker/background_shake"
        private var instance: MainActivity? = null
        private var methodChannel: MethodChannel? = null
        private var pendingShakeEvent: Boolean = false

        fun notifyShakeFromBackground() {
            instance?.runOnUiThread {
                methodChannel?.invokeMethod("onShakeDetected", null)
            } ?: run {
                pendingShakeEvent = true
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun handleIncomingIntent(intent: Intent?) {
        val shouldOpenShake = intent?.getBooleanExtra(ShakeForegroundService.EXTRA_OPEN_SHAKE_EXPENSE, false) ?: false
        if (shouldOpenShake) {
            intent?.removeExtra(ShakeForegroundService.EXTRA_OPEN_SHAKE_EXPENSE)
            notifyShakeFromBackground()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundService" -> {
                    val sensitivity = (call.argument<Double>("sensitivity") ?: 14.0).toFloat()
                    val cooldown = (call.argument<Int>("cooldown") ?: 2000).toLong()

                    val intent = Intent(this, ShakeForegroundService::class.java).apply {
                        action = ShakeForegroundService.ACTION_START
                        putExtra(ShakeForegroundService.EXTRA_SENSITIVITY, sensitivity)
                        putExtra(ShakeForegroundService.EXTRA_COOLDOWN, cooldown)
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }

                "stopBackgroundService" -> {
                    val intent = Intent(this, ShakeForegroundService::class.java).apply {
                        action = ShakeForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(true)
                }

                "isServiceRunning" -> {
                    result.success(ShakeForegroundService.isRunning)
                }

                "checkNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            android.Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        result.success(true)
                    }
                }

                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                            101
                        )
                    }
                    result.success(true)
                }

                "isBatteryOptimizationIgnored" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val ignored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        powerManager?.isIgnoringBatteryOptimizations(packageName) ?: false
                    } else {
                        true
                    }
                    result.success(ignored)
                }

                "requestIgnoreBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        if (powerManager?.isIgnoringBatteryOptimizations(packageName) == false) {
                            try {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (_: Exception) {
                                openBatteryOptimizationSettingsInternal()
                                result.success(false)
                            }
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }

                "openBatteryOptimizationSettings" -> {
                    openBatteryOptimizationSettingsInternal()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        // Check if there was a pending shake from launch
        if (pendingShakeEvent) {
            pendingShakeEvent = false
            notifyShakeFromBackground()
        }
    }

    private fun openBatteryOptimizationSettingsInternal() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                startActivity(intent)
            }
        } catch (_: Exception) {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        }
    }

    override fun onDestroy() {
        if (instance == this) {
            instance = null
        }
        super.onDestroy()
    }
}
