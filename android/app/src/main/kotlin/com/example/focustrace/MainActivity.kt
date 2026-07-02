package com.example.focustrace

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "openUsageAccessSettings" -> {
                        openUsageAccessSettings()
                        result.success(null)
                    }
                    "getTodayUsageStats" -> {
                        if (!hasUsageAccess()) {
                            result.error(
                                "USAGE_ACCESS_DENIED",
                                "Usage access permission has not been granted.",
                                null
                            )
                        } else {
                            result.success(getTodayUsageStats())
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }

        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings() {
        val usageSettingsIntent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        try {
            startActivity(usageSettingsIntent)
        } catch (_: ActivityNotFoundException) {
            startActivity(
                Intent(Settings.ACTION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun getTodayUsageStats(): List<Map<String, Any>> {
        val usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val startOfToday = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        val totals = HashMap<String, Long>()
        val foregroundSince = HashMap<String, Long>()
        val lastUsed = HashMap<String, Long>()

        val events = usageStatsManager.queryEvents(startOfToday, now)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName ?: continue
            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    foregroundSince[packageName] = event.timeStamp
                    lastUsed[packageName] = event.timeStamp
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val start = foregroundSince.remove(packageName)
                    if (start != null && event.timeStamp > start) {
                        totals[packageName] =
                            (totals[packageName] ?: 0L) + (event.timeStamp - start)
                    }
                    lastUsed[packageName] = event.timeStamp
                }
            }
        }

        // Apps still in the foreground at query time have no closing event.
        for ((packageName, start) in foregroundSince) {
            if (now > start) {
                totals[packageName] = (totals[packageName] ?: 0L) + (now - start)
                lastUsed[packageName] = now
            }
        }

        return totals
            .filter { it.value > 0L }
            .map { (packageName, totalMs) ->
                val lastUsedMs = lastUsed[packageName] ?: now
                mapOf(
                    "packageName" to packageName,
                    "appName" to appLabelFor(packageName),
                    "totalTimeInForegroundMs" to totalMs,
                    "firstTimeStampMs" to startOfToday,
                    "lastTimeStampMs" to lastUsedMs,
                    "lastTimeUsedMs" to lastUsedMs
                )
            }
            .sortedByDescending { it["totalTimeInForegroundMs"] as Long }
    }

    private fun appLabelFor(packageName: String): String {
        return try {
            val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(applicationInfo).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            packageName
        }
    }

    private companion object {
        const val CHANNEL_NAME = "focustrace/usage"
    }
}
