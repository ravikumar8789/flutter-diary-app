package com.zen.diaryapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import io.flutter.FlutterInjector

/**
 * Boot receiver to reschedule alarms after device restart or app update
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("BootReceiver", "Received intent: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON" -> {
                Log.d("BootReceiver", "Device booted or app updated - rescheduling alarms")
                
                // Get SharedPreferences to check if there are any scheduled alarms
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                
                // Check if we have any saved alarm times
                val hasAlarms = prefs.contains("flutter.alarm_1001_time") ||
                               prefs.contains("flutter.alarm_1002_time") ||
                               prefs.contains("flutter.alarm_1003_time") ||
                               prefs.contains("flutter.alarm_2001_time")
                
                if (hasAlarms) {
                    Log.d("BootReceiver", "Found saved alarms - triggering reschedule")
                    
                    // Send broadcast to trigger reschedule
                    val rescheduleIntent = Intent(context, RescheduleReceiver::class.java)
                    context.sendBroadcast(rescheduleIntent)
                } else {
                    Log.d("BootReceiver", "No saved alarms found")
                }
            }
        }
    }
}

