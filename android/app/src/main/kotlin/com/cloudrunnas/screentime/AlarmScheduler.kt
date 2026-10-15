package com.cloudrunnas.screentime

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log

object AlarmScheduler {
    private const val REQUEST_CODE = 1001
    const val ACTION_LIMIT_REACHED = "com.cloudrunnas.screentime.LIMIT_REACHED"

    private fun alarmManager(ctx: Context) =
        ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun intent(ctx: Context) =
        Intent(ctx, LimitReachedReceiver::class.java).setAction(ACTION_LIMIT_REACHED)

    fun canScheduleExact(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager(ctx).canScheduleExactAlarms()

    /** [triggerAtElapsed] is a SystemClock.elapsedRealtime() value. */
    fun scheduleAt(ctx: Context, triggerAtElapsed: Long) {
        val pendingIntent = PendingIntent.getBroadcast(
            ctx,
            REQUEST_CODE,
            intent(ctx),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val am = alarmManager(ctx)
        val inSeconds = (triggerAtElapsed - SystemClock.elapsedRealtime()) / 1000
        try {
            if (canScheduleExact(ctx)) {
                am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtElapsed, pendingIntent)
                Log.i(TAG, "exact alarm scheduled in ${inSeconds}s")
            } else {
                am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtElapsed, pendingIntent)
                Log.w(TAG, "exact alarms not allowed, inexact alarm scheduled in ${inSeconds}s")
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "exact alarm rejected, falling back to inexact", e)
            am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtElapsed, pendingIntent)
        }
    }

    fun cancel(ctx: Context) {
        val pendingIntent = PendingIntent.getBroadcast(
            ctx,
            REQUEST_CODE,
            intent(ctx),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        alarmManager(ctx).cancel(pendingIntent)
        pendingIntent.cancel()
    }
}
