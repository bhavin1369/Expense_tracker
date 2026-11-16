package com.fintech.expensetracker.expense_tracker

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.*
import androidx.core.app.NotificationCompat
import kotlin.math.sqrt

class ShakeForegroundService : Service(), SensorEventListener {

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var lastShakeTimestamp: Long = 0
    private var firstPeakTimestamp: Long = 0
    private var peakCount: Int = 0

    private var sensitivity: Float = 14.0f
    private var cooldownMs: Long = 2000L

    companion object {
        const val CHANNEL_SERVICE_ID = "shake_service_persistent_channel"
        const val CHANNEL_ALERT_ID = "shake_alert_heads_up_channel"
        const val NOTIFICATION_SERVICE_ID = 1001
        const val NOTIFICATION_ALERT_ID = 1002

        const val ACTION_START = "ACTION_START_SHAKE_SERVICE"
        const val ACTION_STOP = "ACTION_STOP_SHAKE_SERVICE"
        const val EXTRA_SENSITIVITY = "EXTRA_SENSITIVITY"
        const val EXTRA_COOLDOWN = "EXTRA_COOLDOWN"
        const val EXTRA_OPEN_SHAKE_EXPENSE = "OPEN_SHAKE_EXPENSE"

        const val PREFS_NAME = "shake_service_prefs"
        const val KEY_SERVICE_ENABLED = "service_enabled"
        const val KEY_SENSITIVITY = "saved_sensitivity"
        const val KEY_COOLDOWN = "saved_cooldown"

        var isRunning: Boolean = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null && intent.action == ACTION_STOP) {
            stopForegroundService()
            return START_NOT_STICKY
        }

        // Read sensitivity & cooldown from intent or SharedPreferences
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        sensitivity = intent?.getFloatExtra(EXTRA_SENSITIVITY, prefs.getFloat(KEY_SENSITIVITY, 14.0f)) ?: 14.0f
        cooldownMs = intent?.getLongExtra(EXTRA_COOLDOWN, prefs.getLong(KEY_COOLDOWN, 2000L)) ?: 2000L

        // Save state so BootReceiver can check on reboot
        prefs.edit()
            .putBoolean(KEY_SERVICE_ENABLED, true)
            .putFloat(KEY_SENSITIVITY, sensitivity)
            .putLong(KEY_COOLDOWN, cooldownMs)
            .apply()

        startAsForeground()
        registerSensorListener()
        isRunning = true

        return START_STICKY
    }

    private fun startAsForeground() {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_SERVICE_ID)
            .setContentTitle("Shake Expense Detection Active")
            .setContentText("Shake your phone anytime to record an expense")
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setShowWhen(false)
            .build()

        startForeground(NOTIFICATION_SERVICE_ID, notification)
    }

    private fun registerSensorListener() {
        accelerometer?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
    }

    private fun unregisterSensorListener() {
        sensorManager?.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_ACCELEROMETER) return

        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]

        val totalAcceleration = sqrt((x * x + y * y + z * z).toDouble()).toFloat()
        val netAcceleration = Math.abs(totalAcceleration - SensorManager.GRAVITY_EARTH)

        if (netAcceleration > sensitivity) {
            val now = System.currentTimeMillis()

            if (now - firstPeakTimestamp > 400) {
                peakCount = 1
                firstPeakTimestamp = now
            } else {
                peakCount++
            }

            if (peakCount >= 2 || netAcceleration > (sensitivity * 1.35f)) {
                if (now - lastShakeTimestamp > cooldownMs) {
                    lastShakeTimestamp = now
                    peakCount = 0
                    handleShakeDetected()
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun handleShakeDetected() {
        vibratePhone()

        val canDrawOverlay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            android.provider.Settings.canDrawOverlays(this)
        } else {
            true
        }

        if (canDrawOverlay) {
            // DIRECT FLOATING EXPENSE POPUP ON SHAKE OVER ANY APP
            Handler(Looper.getMainLooper()).post {
                FloatingExpenseOverlay.show(this)
            }
        } else {
            // 1. Notify Flutter if alive
            MainActivity.notifyShakeFromBackground()

            // 2. Alert user that overlay permission is required
            postOverlayPermissionAlertNotification()
        }
    }

    private fun postOverlayPermissionAlertNotification() {
        val permissionIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent(
                android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                android.net.Uri.parse("package:$packageName")
            ).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
        } else {
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            2,
            permissionIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val alertNotification = NotificationCompat.Builder(this, CHANNEL_ALERT_ID)
            .setContentTitle("Display Over Other Apps Needed ⚠️")
            .setContentText("Tap to allow overlay permission so expense popups appear directly on shake")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_menu_preferences, "Open Settings", pendingIntent)
            .build()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        notificationManager?.notify(NOTIFICATION_ALERT_ID, alertNotification)
    }

    @Suppress("DEPRECATION")
    private fun vibratePhone() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibratorManager?.defaultVibrator?.vibrate(
                    VibrationEffect.createOneShot(350, VibrationEffect.DEFAULT_AMPLITUDE)
                )
            } else {
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator?.vibrate(VibrationEffect.createOneShot(350, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    vibrator?.vibrate(350)
                }
            }
        } catch (_: Exception) {}
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

            // Channel 1: Persistent Service Notification
            val serviceChannel = NotificationChannel(
                CHANNEL_SERVICE_ID,
                "Shake Detection Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows that the background shake detection service is running"
                setShowBadge(false)
            }

            // Channel 2: High Priority Heads-up Shake Alert Notification
            val alertChannel = NotificationChannel(
                CHANNEL_ALERT_ID,
                "Shake Detection Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts you when a shake is detected so you can add an expense"
                enableVibration(true)
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }

            manager.createNotificationChannel(serviceChannel)
            manager.createNotificationChannel(alertChannel)
        }
    }

    private fun stopForegroundService() {
        isRunning = false
        unregisterSensorListener()
        FloatingExpenseOverlay.dismiss()
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_SERVICE_ENABLED, false).apply()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        isRunning = false
        unregisterSensorListener()
        FloatingExpenseOverlay.dismiss()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
