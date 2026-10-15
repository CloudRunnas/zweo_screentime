package com.cloudrunnas.screentime

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Bridge between Flutter and the native screen time logic: channel "screen_time/control". */
class ScreenTimeChannel private constructor(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        private const val NAME = "screen_time/control"
        const val EXTRA_PREVIEW = "preview"

        fun register(engine: FlutterEngine, activity: Activity) {
            MethodChannel(engine.dartExecutor.binaryMessenger, NAME)
                .setMethodCallHandler(ScreenTimeChannel(activity))
        }

        /** Known OEM pages for autostart / background restrictions. First one that starts wins. */
        private val autostartComponents = listOf(
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
            ComponentName("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
            ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
            ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
            ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"),
            ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity"),
            ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.MainActivity"),
        )
    }

    private val ctx get() = activity.applicationContext
    private val packageUri get() = Uri.parse("package:${ctx.packageName}")

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getSettings" -> result.success(settingsMap())
                "saveSettings" -> {
                    val oldLimit = Prefs.limitMinutes(ctx)
                    Prefs.saveSettings(
                        ctx,
                        limitMinutes = call.argument<Int>("limitMinutes") ?: Prefs.limitMinutes(ctx),
                        snoozeMinutes = call.argument<Int>("snoozeMinutes") ?: Prefs.snoozeMinutes(ctx),
                        graceSeconds = call.argument<Int>("graceSeconds") ?: Prefs.graceSeconds(ctx),
                        warningTitle = call.argument<String>("warningTitle") ?: "",
                        warningText = call.argument<String>("warningText") ?: "",
                    )
                    if (Prefs.limitMinutes(ctx) != oldLimit) Session.onLimitChanged(ctx)
                    result.success(settingsMap())
                }
                "resetSettings" -> {
                    val oldLimit = Prefs.limitMinutes(ctx)
                    Prefs.resetSettings(ctx)
                    if (Prefs.limitMinutes(ctx) != oldLimit) Session.onLimitChanged(ctx)
                    result.success(settingsMap())
                }
                "startMonitoring" -> {
                    Prefs.setEnabled(ctx, true)
                    Session.reset(ctx)
                    if (ScreenTimeService.isRunning) {
                        // onCreate will not run again, start the session here.
                        Session.onUserActive(ctx)
                    } else {
                        ScreenTimeService.start(ctx)
                    }
                    result.success(null)
                }
                "stopMonitoring" -> {
                    Prefs.setEnabled(ctx, false)
                    Session.reset(ctx)
                    ScreenTimeService.stop(ctx)
                    Notifications.cancelWarning(ctx)
                    result.success(null)
                }
                "getStatus" -> {
                    val deadline = Prefs.deadline(ctx)
                    val running = Session.isRunning(ctx)
                    result.success(
                        mapOf(
                            "enabled" to Prefs.isEnabled(ctx),
                            "serviceRunning" to ScreenTimeService.isRunning,
                            "sessionStartedAt" to if (running) Session.toEpochMillis(Prefs.sessionStartedAt(ctx)) else null,
                            "nextWarningAt" to if (running && deadline > 0) Session.toEpochMillis(deadline) else null,
                            "warningDismissed" to (running && deadline == Session.DISMISSED),
                        )
                    )
                }
                "getWarning" -> {
                    val preview = activity.intent?.getBooleanExtra(EXTRA_PREVIEW, false) ?: false
                    val minutes = if (preview) Prefs.limitMinutes(ctx).toLong() else Session.elapsedMinutes(ctx)
                    result.success(
                        mapOf(
                            "title" to Prefs.warningTitle(ctx),
                            "text" to Prefs.formatWarningText(ctx, minutes),
                            "snoozeMinutes" to Prefs.snoozeMinutes(ctx),
                            "preview" to preview,
                        )
                    )
                }
                "snooze" -> {
                    Notifications.cancelWarning(ctx)
                    Session.snooze(ctx)
                    result.success(null)
                }
                "dismissWarning" -> {
                    Notifications.cancelWarning(ctx)
                    Session.dismiss(ctx)
                    result.success(null)
                }
                "previewWarning" -> {
                    activity.startActivity(
                        Intent(activity, LimitActivity::class.java)
                            .putExtra(EXTRA_PREVIEW, true)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    )
                    result.success(null)
                }

                "getDeviceInfo" -> result.success(
                    mapOf("manufacturer" to Build.MANUFACTURER, "sdkInt" to Build.VERSION.SDK_INT)
                )
                "areNotificationsEnabled" -> result.success(NotificationManagerCompat.from(ctx).areNotificationsEnabled())
                "openNotificationSettings" -> result.success(openNotificationSettings())
                "requestNotificationPermission" -> result.success(requestNotificationPermission())
                "canScheduleExactAlarms" -> result.success(AlarmScheduler.canScheduleExact(ctx))
                "openExactAlarmSettings" -> result.success(
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                        start(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, packageUri))
                )
                "canDrawOverlays" -> result.success(Settings.canDrawOverlays(ctx))
                "openOverlaySettings" -> result.success(
                    start(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, packageUri))
                )
                "canUseFullScreenIntent" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
                        ctx.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
                )
                "openFullScreenIntentSettings" -> result.success(
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
                        start(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, packageUri))
                )
                "isIgnoringBatteryOptimizations" -> {
                    val power = ctx.getSystemService(PowerManager::class.java)
                    result.success(power.isIgnoringBatteryOptimizations(ctx.packageName))
                }
                "requestIgnoreBatteryOptimizations" -> result.success(
                    start(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, packageUri)) ||
                        start(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                )
                "getHibernationStatus" -> result.success(hibernationStatus())
                "openHibernationSettings" -> result.success(openHibernationSettings())
                "openAutostartSettings" -> result.success(openAutostartSettings())
                "openAppDetails" -> result.success(openAppDetails())
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e(TAG, "channel call ${call.method} failed", e)
            result.error("NATIVE_ERROR", e.message ?: e.javaClass.simpleName, null)
        }
    }

    private fun settingsMap() = mapOf(
        "limitMinutes" to Prefs.limitMinutes(ctx),
        "snoozeMinutes" to Prefs.snoozeMinutes(ctx),
        "graceSeconds" to Prefs.graceSeconds(ctx),
        "warningTitle" to Prefs.rawWarningTitle(ctx),
        "warningText" to Prefs.rawWarningText(ctx),
        "defaultWarningTitle" to Prefs.DEFAULT_WARNING_TITLE,
        "defaultWarningText" to Prefs.DEFAULT_WARNING_TEXT,
    )

    /** Starts a settings activity; false if no activity handles the intent. */
    private fun start(intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (e: Exception) {
        Log.w(TAG, "could not open ${intent.action ?: intent.component}", e)
        false
    }

    private fun openAppDetails() =
        start(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri))

    private fun openNotificationSettings(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
            if (start(intent)) return true
        }
        return openAppDetails()
    }

    /**
     * Android 13+: the first request shows the system dialog. Android does not show it again once
     * the user denied it, so later calls (and older versions) open the notification settings.
     */
    private fun requestNotificationPermission(): Boolean {
        val prefs = ctx.getSharedPreferences("screen_time_ui", Context.MODE_PRIVATE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            !prefs.getBoolean("notificationPermissionRequested", false)
        ) {
            prefs.edit().putBoolean("notificationPermissionRequested", true).apply()
            ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4711)
            return true
        }
        return openNotificationSettings()
    }

    /**
     * "Pause app activity if unused" (API 31+) / "Remove permissions if unused" (API 30).
     * Both are controlled by the auto-revoke exemption, which isAutoRevokeWhitelisted reports.
     */
    private fun hibernationStatus(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return "notApplicable"
        return if (ctx.packageManager.isAutoRevokeWhitelisted) "ok" else "restricted"
    }

    private fun openHibernationSettings(): Boolean {
        if (Build.VERSION.SDK_INT == Build.VERSION_CODES.R &&
            start(Intent("android.intent.action.AUTO_REVOKE_PERMISSIONS", packageUri))
        ) return true
        return openAppDetails()
    }

    /** Returns "autostart" if an OEM page was opened, "appDetails" for the fallback. */
    private fun openAutostartSettings(): String {
        for (component in autostartComponents) {
            if (start(Intent().setComponent(component))) return "autostart"
        }
        openAppDetails()
        return "appDetails"
    }
}
