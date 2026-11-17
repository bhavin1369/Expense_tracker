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
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlin.math.abs
import kotlin.math.sqrt

class ShakeForegroundService : Service(), SensorEventListener {

    private var sensorManager: SensorManager? = null
    private var activeSensor: Sensor? = null
    private var gyroSensor: Sensor? = null
    private var isUsingLinearAcceleration: Boolean = false

    // Gravity filter fallback when TYPE_LINEAR_ACCELERATION is not available
    private val gravity = FloatArray(3) { 0f }
    private var hasGravityInitialized = false

    // Gyroscope tracking to confirm real angular oscillation
    private var lastGyroMagnitude: Float = 0f

    // Detection state machine variables
    private var peakCount: Int = 0
    private var firstPeakTimestamp: Long = 0L
    private var lastPeakTimestamp: Long = 0L
    private var lastTriggerTimestamp: Long = 0L
    private var waitingForValley: Boolean = false
    private var lastPeakAxis: Int = 0 // 0: X, 1: Y, 2: Z
    private var lastPeakSign: Float = 1.0f

    // Configurable parameters
    private var sensitivity: Float = DEFAULT_SENSITIVITY
    private var cooldownMs: Long = DEFAULT_COOLDOWN_MS

    companion object {
        private const val TAG = "ShakeService"

        const val CHANNEL_SERVICE_ID = "shake_service_persistent_channel"
        const val CHANNEL_ALERT_ID = "shake_alert_heads_up_channel"
        const val NOTIFICATION_SERVICE_ID = 1001
        const val NOTIFICATION_ALERT_ID = 1002

        const val ACTION_START = "ACTION_START_SHAKE_SERVICE"
        const val ACTION_STOP = "ACTION_STOP_SHAKE_SERVICE"
        const val ACTION_UPDATE_CONFIG = "ACTION_UPDATE_SHAKE_CONFIG"

        const val EXTRA_SENSITIVITY = "EXTRA_SENSITIVITY"
        const val EXTRA_COOLDOWN = "EXTRA_COOLDOWN"
        const val EXTRA_OPEN_SHAKE_EXPENSE = "OPEN_SHAKE_EXPENSE"

        const val PREFS_NAME = "shake_service_prefs"
        const val KEY_SERVICE_ENABLED = "service_enabled"
        const val KEY_SENSITIVITY = "saved_sensitivity"
        const val KEY_COOLDOWN = "saved_cooldown"

        // Detection constants - mathematically calibrated to eliminate walking/stairs
        const val DEFAULT_SENSITIVITY = 3.2f // m/s^2 linear acceleration
        const val DEFAULT_COOLDOWN_MS = 2500L
        const val MIN_PEAKS = 4 // Require at least 4 alternating peaks
        const val MAX_WINDOW_MS = 1100L // 1.1s total window
        const val MIN_TIME_BETWEEN_PEAKS_MS = 100L // Filter out engine vibrations (>10Hz)
        const val MAX_TIME_BETWEEN_PEAKS_MS = 300L // Maximum time between consecutive peaks (walking cadence is ~500ms!)
        const val VALLEY_RATIO = 0.40f // Must drop below 40% threshold between peaks

        var isRunning: Boolean = false
            private set

        private var activeServiceInstance: ShakeForegroundService? = null

        fun updateRunningConfig(newSensitivity: Float, newCooldown: Long) {
            activeServiceInstance?.let { service ->
                service.sensitivity = if (newSensitivity > 6.0f) DEFAULT_SENSITIVITY else newSensitivity
                service.cooldownMs = newCooldown
                Log.d(TAG, "Updated running service config: sensitivity=${service.sensitivity}, cooldown=${service.cooldownMs}")
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        activeServiceInstance = this
        createNotificationChannels()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager

        // Prefer TYPE_LINEAR_ACCELERATION (hardware sensor fusion with gravity removed in 3D)
        val linearSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
        if (linearSensor != null) {
            activeSensor = linearSensor
            isUsingLinearAcceleration = true
            Log.d(TAG, "Initialized with Sensor.TYPE_LINEAR_ACCELERATION")
        } else {
            activeSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            isUsingLinearAcceleration = false
            Log.d(TAG, "Initialized with fallback Sensor.TYPE_ACCELEROMETER + 3D LPF")
        }

        // Gyroscope sensor to confirm manual oscillation
        gyroSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null && intent.action == ACTION_STOP) {
            stopForegroundService()
            return START_NOT_STICKY
        }

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val rawSavedSens = prefs.getFloat(KEY_SENSITIVITY, DEFAULT_SENSITIVITY)
        // Migrate legacy raw accelerometer threshold (>6.0) to linear threshold
        val initialSens = if (rawSavedSens > 6.0f) DEFAULT_SENSITIVITY else rawSavedSens

        val requestedSens = intent?.getFloatExtra(EXTRA_SENSITIVITY, initialSens) ?: initialSens
        sensitivity = if (requestedSens > 6.0f) DEFAULT_SENSITIVITY else requestedSens
        cooldownMs = intent?.getLongExtra(EXTRA_COOLDOWN, prefs.getLong(KEY_COOLDOWN, DEFAULT_COOLDOWN_MS)) ?: DEFAULT_COOLDOWN_MS

        if (intent?.action == ACTION_UPDATE_CONFIG) {
            Log.d(TAG, "Received ACTION_UPDATE_CONFIG: sensitivity=$sensitivity, cooldown=$cooldownMs")
            prefs.edit()
                .putFloat(KEY_SENSITIVITY, sensitivity)
                .putLong(KEY_COOLDOWN, cooldownMs)
                .apply()
            return START_STICKY
        }

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
        activeSensor?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
        gyroSensor?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    private fun unregisterSensorListener() {
        sensorManager?.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return

        // Track Gyroscope angular rate
        if (event.sensor.type == Sensor.TYPE_GYROSCOPE) {
            val gx = event.values[0]
            val gy = event.values[1]
            val gz = event.values[2]
            lastGyroMagnitude = sqrt((gx * gx + gy * gy + gz * gz).toDouble()).toFloat()
            return
        }

        if (event.sensor != activeSensor) return

        var linX: Float
        var linY: Float
        var linZ: Float

        if (isUsingLinearAcceleration) {
            linX = event.values[0]
            linY = event.values[1]
            linZ = event.values[2]
        } else {
            // Apply 3D low-pass filter to extract gravity, then subtract
            val alpha = 0.8f
            if (!hasGravityInitialized) {
                gravity[0] = event.values[0]
                gravity[1] = event.values[1]
                gravity[2] = event.values[2]
                hasGravityInitialized = true
            } else {
                gravity[0] = alpha * gravity[0] + (1 - alpha) * event.values[0]
                gravity[1] = alpha * gravity[1] + (1 - alpha) * event.values[1]
                gravity[2] = alpha * gravity[2] + (1 - alpha) * event.values[2]
            }
            linX = event.values[0] - gravity[0]
            linY = event.values[1] - gravity[1]
            linZ = event.values[2] - gravity[2]
        }

        val magnitude = sqrt((linX * linX + linY * linY + linZ * linZ).toDouble()).toFloat()
        val now = System.currentTimeMillis()

        // 1. Check Cooldown
        if (now - lastTriggerTimestamp < cooldownMs) {
            return
        }

        // 2. Window and Inter-Peak Timeout Validation
        // Walking cadence is ~500ms between steps. Human shake is 100-300ms between reversals.
        if (peakCount > 0) {
            val elapsedSinceFirst = now - firstPeakTimestamp
            val elapsedSinceLast = now - lastPeakTimestamp

            if (elapsedSinceFirst > MAX_WINDOW_MS || elapsedSinceLast > MAX_TIME_BETWEEN_PEAKS_MS) {
                // Rhythm broken or step cadence timed out -> reset to zero immediately
                peakCount = 0
                waitingForValley = false
            }
        }

        // 3. Valley / Hysteresis Validation
        val valleyThreshold = sensitivity * VALLEY_RATIO
        if (waitingForValley) {
            if (magnitude < valleyThreshold) {
                waitingForValley = false
            } else {
                // Check if dominant axis reversed direction significantly
                val dominantVal = when (lastPeakAxis) {
                    0 -> linX
                    1 -> linY
                    else -> linZ
                }
                if ((dominantVal * lastPeakSign) < -valleyThreshold) {
                    waitingForValley = false
                }
            }
        }

        // 4. Peak Detection and Pattern Validation
        if (!waitingForValley && magnitude >= sensitivity) {
            val timeSinceLast = if (peakCount == 0) 999999L else (now - lastPeakTimestamp)

            if (timeSinceLast >= MIN_TIME_BETWEEN_PEAKS_MS) {
                // Find dominant axis and sign
                val absX = abs(linX)
                val absY = abs(linY)
                val absZ = abs(linZ)
                var domAxis = 0
                var domVal = linX
                if (absY > absX && absY > absZ) {
                    domAxis = 1
                    domVal = linY
                } else if (absZ > absX && absZ > absY) {
                    domAxis = 2
                    domVal = linZ
                }
                val domSign = if (domVal >= 0) 1.0f else -1.0f

                // CRITICAL ROOT-CAUSE FIX: Enforce strict alternating direction reversal!
                // Walking, stair climbing/descending, running, and pocket removal produce unilateral peaks
                // in the same direction on the dominant axis.
                // A genuine shake MUST reverse direction back and forth (+ -> - -> + -> -)!
                if (peakCount > 0) {
                    if (domAxis == lastPeakAxis && domSign == lastPeakSign) {
                        // Same sign in succession -> Unilateral footfall/impact! Reject!
                        return
                    }
                }

                peakCount++
                lastPeakTimestamp = now
                waitingForValley = true
                lastPeakAxis = domAxis
                lastPeakSign = domSign

                if (peakCount == 1) {
                    firstPeakTimestamp = now
                }

                // 5. Require at least 4 distinct alternating peaks
                if (peakCount >= MIN_PEAKS) {
                    // Optional gyro check if gyroscope is present: require minimal angular oscillation (> 1.2 rad/s)
                    if (gyroSensor != null && lastGyroMagnitude < 1.2f) {
                        // Translation-only vibration (like vehicle or train bumping) without wrist rotation -> ignore
                        return
                    }

                    lastTriggerTimestamp = now
                    peakCount = 0
                    waitingForValley = false
                    handleShakeDetected()
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun handleShakeDetected() {
        // COORDINATION: If Flutter app is active in foreground, let Flutter handle it!
        // This prevents duplicate triggers and prevents native overlay over the app itself.
        if (MainActivity.isAppInForeground) {
            Log.d(TAG, "Shake detected but Flutter app is in foreground. Skipping native overlay.")
            return
        }

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
            // Alert user that overlay permission is required
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

            val serviceChannel = NotificationChannel(
                CHANNEL_SERVICE_ID,
                "Shake Detection Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows that the background shake detection service is running"
                setShowBadge(false)
            }

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
        activeServiceInstance = null
        unregisterSensorListener()
        FloatingExpenseOverlay.dismiss()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
