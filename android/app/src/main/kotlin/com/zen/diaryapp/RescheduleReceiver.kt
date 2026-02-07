package com.zen.diaryapp

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Receiver to handle rescheduling of alarms from SharedPreferences
 */
class RescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("RescheduleReceiver", "Rescheduling alarms from SharedPreferences")
        
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val currentTime = System.currentTimeMillis()
        
        val allEntries = prefs.all
        for ((key, value) in allEntries) {
            if (!key.startsWith("flutter.alarm_") || !key.endsWith("_time")) {
                continue
            }

            val timeStr = value as? String ?: continue
            val baseKey = key.removeSuffix("_time")
            val title = prefs.getString("${baseKey}_title", null)
            val body = prefs.getString("${baseKey}_body", null)
            if (title == null || body == null) continue

            val idPart = baseKey.removePrefix("flutter.alarm_").split("_").firstOrNull()
            val alarmId = idPart?.toIntOrNull() ?: continue

            try {
                // Parse ISO 8601 datetime
                val scheduledTimeMillis = parseIso8601(timeStr)

                // Only reschedule if time is in the future
                if (scheduledTimeMillis > currentTime) {
                    Log.d("RescheduleReceiver", "Rescheduling alarm $alarmId for $timeStr")

                    val notificationIntent = Intent(context, NotificationReceiver::class.java).apply {
                        putExtra("notification_id", alarmId)
                        putExtra("title", title)
                        putExtra("body", body)
                    }

                    val pendingIntent = PendingIntent.getBroadcast(
                        context,
                        alarmId,
                        notificationIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    // Schedule the alarm
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            scheduledTimeMillis,
                            pendingIntent
                        )
                    } else {
                        alarmManager.setExact(
                            AlarmManager.RTC_WAKEUP,
                            scheduledTimeMillis,
                            pendingIntent
                        )
                    }

                    Log.d("RescheduleReceiver", "Successfully rescheduled alarm $alarmId")
                } else {
                    Log.d("RescheduleReceiver", "Alarm $alarmId time has passed, skipping")
                }
            } catch (e: Exception) {
                Log.e("RescheduleReceiver", "Error rescheduling alarm $alarmId: ${e.message}")
            }
        }
    }
    
    /**
     * Parse ISO 8601 datetime string to milliseconds
     * Format: 2025-10-24T17:30:00.000
     */
    private fun parseIso8601(dateTimeStr: String): Long {
        // Remove 'Z' if present and handle timezone
        val cleanStr = dateTimeStr.replace("Z", "")
        
        // Parse using SimpleDateFormat
        val format = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", java.util.Locale.US)
        format.timeZone = java.util.TimeZone.getDefault()
        
        return format.parse(cleanStr)?.time ?: 0L
    }
}

