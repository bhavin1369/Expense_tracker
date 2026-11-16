package com.fintech.expensetracker.expense_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        val receivedAction = intent.action
        if (receivedAction == Intent.ACTION_BOOT_COMPLETED || receivedAction == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val prefs = context.getSharedPreferences(ShakeForegroundService.PREFS_NAME, Context.MODE_PRIVATE)
            val isEnabled = prefs.getBoolean(ShakeForegroundService.KEY_SERVICE_ENABLED, false)

            if (isEnabled) {
                val serviceIntent = Intent(context, ShakeForegroundService::class.java)
                serviceIntent.action = ShakeForegroundService.ACTION_START
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
        }
    }
}
