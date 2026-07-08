package com.example.focustrace

import android.Manifest
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Calendar

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "hasOverlayPermission" -> result.success(
                        FocusTracePermissions.hasOverlayPermission(this)
                    )
                    "openUsageAccessSettings" -> {
                        openUsageAccessSettings()
                        result.success(null)
                    }
                    "openOverlaySettings" -> {
                        openOverlaySettings()
                        result.success(null)
                    }
                    "requestNotificationsPermission" -> {
                        requestNotificationsPermission()
                        result.success(null)
                    }
                    "syncRestrictions" -> {
                        syncRestrictions(call.arguments as? String ?: "")
                        result.success(null)
                    }
                    "getInstalledApps" -> {
                        // Icon encoding for every launchable app is too slow
                        // for the main thread.
                        Thread {
                            try {
                                val apps = getInstalledApps()
                                runOnUiThread { result.success(apps) }
                            } catch (e: Exception) {
                                Log.e(LOG_TAG, "getInstalledApps failed", e)
                                runOnUiThread {
                                    result.error(
                                        "INSTALLED_APPS_FAILED",
                                        e.message,
                                        null
                                    )
                                }
                            }
                        }.start()
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
        return FocusTracePermissions.hasUsageAccess(this)
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

    private fun openOverlaySettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        try {
            startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            startActivity(
                Intent(Settings.ACTION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    private fun requestNotificationsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE
            )
        }
    }

    private fun syncRestrictions(json: String) {
        getSharedPreferences(RestrictionRules.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(RestrictionRules.PREFS_RULES_KEY, json)
            .apply()

        val serviceIntent = Intent(this, BlockerService::class.java)
        if (
            RestrictionRules.hasRules(json) &&
            FocusTracePermissions.hasOverlayPermission(this) &&
            hasUsageAccess()
        ) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        } else {
            stopService(serviceIntent)
        }
    }

    @Suppress("DEPRECATION")
    private fun getTodayUsageStats(): List<Map<String, Any?>> {
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
            .filter { it.value > 0L && isUserFacingApp(it.key) }
            .map { (packageName, totalMs) ->
                val lastUsedMs = lastUsed[packageName] ?: now
                mapOf(
                    "packageName" to packageName,
                    "appName" to appLabelFor(packageName),
                    "iconBytes" to appIconFor(packageName),
                    "totalTimeInForegroundMs" to totalMs,
                    "firstTimeStampMs" to startOfToday,
                    "lastTimeStampMs" to lastUsedMs,
                    "lastTimeUsedMs" to lastUsedMs
                )
            }
            .sortedByDescending { it["totalTimeInForegroundMs"] as Long }
    }

    // ponytail: launchable-in-app-drawer is the system-app filter; whitelist packages here if a wanted app gets dropped.
    private fun isUserFacingApp(packageName: String): Boolean {
        return packageManager.getLaunchIntentForPackage(packageName) != null
    }

    /** All launchable apps: popular apps first, then the rest by label. */
    @Suppress("DEPRECATION")
    private fun getInstalledApps(): List<Map<String, Any?>> {
        val popular = listOf(
            "com.zhiliaoapp.musically",
            "com.instagram.android",
            "com.google.android.youtube",
            "com.discord",
            "org.telegram.messenger",
            "com.whatsapp",
            "com.snapchat.android",
            "com.facebook.katana",
            "com.twitter.android",
            "com.reddit.frontpage"
        )
        val launchable = packageManager.getInstalledApplications(0)
            .map { it.packageName }
            .filter { it != packageName && isUserFacingApp(it) }
        val popularFirst = popular.filter(launchable::contains)
        val rest = launchable
            .filterNot(popularFirst::contains)
            .sortedBy { appLabelFor(it).lowercase() }
        return (popularFirst + rest).map { pkg ->
            mapOf(
                "packageName" to pkg,
                "appName" to appLabelFor(pkg),
                "iconBytes" to appIconFor(pkg)
            )
        }
    }

    private val iconCache = HashMap<String, ByteArray?>()

    // Called from both the main thread (usage stats) and the installed-apps
    // worker thread, so the cache access must be synchronized.
    private fun appIconFor(packageName: String): ByteArray? = synchronized(iconCache) {
        return iconCache.getOrPut(packageName) {
            try {
                val drawable = packageManager.getApplicationIcon(packageName)
                val size = 128
                val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
                drawable.setBounds(0, 0, size, size)
                drawable.draw(Canvas(bitmap))
                val out = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                bitmap.recycle()
                out.toByteArray()
            } catch (_: Exception) {
                null
            }
        }
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
        const val LOG_TAG = "FocusTrace"
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 7104
    }
}
