package com.example.focustrace

import android.app.AppOpsManager
import android.app.usage.UsageStats
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

        return usageStatsManager
            .queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startOfToday, now)
            .orEmpty()
            .filter { it.totalTimeInForeground > 0L }
            .groupBy { it.packageName }
            .map { (packageName, usageStats) -> usageStats.toUsageSummary(packageName) }
            .sortedByDescending { it["totalTimeInForegroundMs"] as Long }
    }

    private fun List<UsageStats>.toUsageSummary(packageName: String): Map<String, Any> {
        return mapOf(
            "packageName" to packageName,
            "appName" to appLabelFor(packageName),
            "totalTimeInForegroundMs" to sumOf { it.totalTimeInForeground },
            "firstTimeStampMs" to minOf { it.firstTimeStamp },
            "lastTimeStampMs" to maxOf { it.lastTimeStamp },
            "lastTimeUsedMs" to maxOf { it.lastTimeUsed }
        )
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
