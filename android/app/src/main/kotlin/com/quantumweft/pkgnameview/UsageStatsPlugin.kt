package com.quantumweft.pkgnameview

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.*
import android.app.usage.UsageStats
import android.content.pm.PackageManager

class UsageStatsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "app.usage/stats")
        context = binding.applicationContext
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getUsageStats" -> {
                if (!checkUsageStatsPermission()) {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(intent)
                    result.error("PERMISSION_DENIED", "Usage access permission required", null)
                    return
                }

                val usageStats = getUsageStatistics()
                result.success(usageStats)
            }
            else -> result.notImplemented()
        }
    }

    private fun checkUsageStatsPermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            context.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getUsageStatistics(): List<Map<String, Any>> {
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)

        val queryUsageStats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            calendar.timeInMillis,
            System.currentTimeMillis()
        )

        return queryUsageStats
            .filter { it.totalTimeInForeground > 0 }
            .sortedByDescending { it.totalTimeInForeground }
            .mapNotNull { stats ->
                try {
                    val packageManager = context.packageManager
                    val applicationInfo = packageManager.getApplicationInfo(stats.packageName, 0)
                    
                    mapOf(
                        "packageName" to stats.packageName,
                        "appName" to packageManager.getApplicationLabel(applicationInfo).toString(),
                        "usageTime" to formatDuration(stats.totalTimeInForeground),
                        "lastUsed" to formatLastUsed(stats.lastTimeUsed)
                    )
                } catch (e: Exception) {
                    null
                }
            }
    }

    private fun formatDuration(timeInMillis: Long): String {
        val hours = timeInMillis / (1000 * 60 * 60)
        val minutes = (timeInMillis / (1000 * 60)) % 60
        return when {
            hours > 0 -> "${hours}h ${minutes}m"
            minutes > 0 -> "${minutes}m"
            else -> "< 1m"
        }
    }

    private fun formatLastUsed(timeInMillis: Long): String {
        val now = System.currentTimeMillis()
        val diff = now - timeInMillis
        val hours = diff / (1000 * 60 * 60)
        return when {
            hours < 1 -> "Last used: Recently"
            hours < 24 -> "Last used: ${hours}h ago"
            else -> "Last used: >24h ago"
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
