package com.cloudrunnas.screentime

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

object Notifications {
    private const val CHANNEL_SERVICE = "service"
    private const val CHANNEL_WARNING = "warning"
    const val ID_SERVICE = 1
    private const val ID_WARNING = 2

    fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = ctx.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_SERVICE, "Überwachung aktiv", NotificationManager.IMPORTANCE_MIN).apply {
                description = "Dauerhafte Anzeige, solange die Bildschirmzeit überwacht wird"
                setShowBadge(false)
            }
        )
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_WARNING, "Bildschirmzeit-Warnung", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Warnung, wenn das Zeitlimit erreicht ist"
                enableVibration(true)
            }
        )
    }

    fun serviceNotification(ctx: Context): Notification {
        val openApp = PendingIntent.getActivity(
            ctx,
            0,
            Intent(ctx, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(ctx, CHANNEL_SERVICE)
            .setSmallIcon(R.drawable.ic_stat_timer)
            .setContentTitle("Bildschirmzeit-Überwachung aktiv")
            .setContentText("Limit: ${Prefs.limitMinutes(ctx)} min")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setShowWhen(false)
            .setContentIntent(openApp)
            .build()
    }

    /**
     * Shows the warning. With the overlay permission the full-screen LimitActivity is started
     * directly (works while the phone is in use). Otherwise a high-priority notification with a
     * full-screen intent is posted; while the phone is in use Android shows it as a heads-up.
     */
    fun showWarning(ctx: Context) {
        val activityIntent = Intent(ctx, LimitActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)

        if (Settings.canDrawOverlays(ctx)) {
            try {
                ctx.startActivity(activityIntent)
                Log.i(TAG, "warning shown as full screen activity")
                return
            } catch (e: Exception) {
                Log.e(TAG, "could not start LimitActivity, falling back to notification", e)
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "no notification permission, warning cannot be shown")
            return
        }

        val pendingIntent = PendingIntent.getActivity(
            ctx,
            ID_WARNING,
            activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val text = Prefs.formatWarningText(ctx, Session.intervalMinutes(ctx))
        val notification = NotificationCompat.Builder(ctx, CHANNEL_WARNING)
            .setSmallIcon(R.drawable.ic_stat_timer)
            .setContentTitle(Prefs.warningTitle(ctx))
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true)
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(ctx).notify(ID_WARNING, notification)
        Log.i(TAG, "warning shown as notification")
    }

    fun cancelWarning(ctx: Context) {
        NotificationManagerCompat.from(ctx).cancel(ID_WARNING)
    }
}
