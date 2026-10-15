package com.cloudrunnas.screentime

import android.app.KeyguardManager
import android.content.Context
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log

/**
 * Usage session logic.
 *
 * A session starts when the user unlocks the phone. Its deadline is when the warning is due.
 * Screen off cancels the alarm; unlocking again within the grace period resumes the session
 * (the pause counts as usage), otherwise a new session starts.
 */
object Session {
    /** Deadline value meaning "warning acknowledged, no further alarm in this session". */
    const val DISMISSED = -1L

    private fun now() = SystemClock.elapsedRealtime()

    /** Screen is on and the keyguard is not shown. */
    fun isUserActive(ctx: Context): Boolean {
        val power = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
        val keyguard = ctx.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return power.isInteractive && !keyguard.isKeyguardLocked
    }

    fun onUserActive(ctx: Context) {
        if (!Prefs.isEnabled(ctx)) return
        val now = now()
        val start = Prefs.sessionStartedAt(ctx)
        val screenOff = Prefs.screenOffAt(ctx)
        val graceMs = Prefs.graceSeconds(ctx) * 1000L
        val validSession = start in 1..now
        val withinGrace = screenOff == 0L ||
            (graceMs > 0 && screenOff <= now && now - screenOff <= graceMs)

        if (validSession && withinGrace) {
            Log.i(TAG, "session resumed (started ${(now - start) / 1000}s ago)")
            Prefs.setSession(ctx, screenOffAt = 0L)
        } else {
            val deadline = now + Prefs.limitMinutes(ctx) * 60_000L
            Log.i(TAG, "new session, warning in ${Prefs.limitMinutes(ctx)} min")
            Prefs.setSession(ctx, sessionStartedAt = now, deadline = deadline, screenOffAt = 0L)
        }
        scheduleDeadline(ctx)
    }

    fun onScreenOff(ctx: Context) {
        AlarmScheduler.cancel(ctx)
        if (Prefs.screenOffAt(ctx) == 0L) {
            Prefs.setSession(ctx, screenOffAt = now())
        }
        Log.i(TAG, "screen off, alarm cancelled")
    }

    /** Called when the warning was shown: remind again after the snooze time if ignored. */
    fun onWarningShown(ctx: Context) = snooze(ctx)

    fun snooze(ctx: Context) {
        val deadline = now() + Prefs.snoozeMinutes(ctx) * 60_000L
        Prefs.setSession(ctx, deadline = deadline)
        scheduleDeadline(ctx)
        Log.i(TAG, "snoozed for ${Prefs.snoozeMinutes(ctx)} min")
    }

    fun dismiss(ctx: Context) {
        Prefs.setSession(ctx, deadline = DISMISSED)
        AlarmScheduler.cancel(ctx)
        Log.i(TAG, "warning dismissed until next session")
    }

    /** The limit applies immediately to a running session (US-18). */
    fun onLimitChanged(ctx: Context) {
        if (!Prefs.isEnabled(ctx) || !isRunning(ctx)) return
        if (Prefs.deadline(ctx) == DISMISSED) return
        val deadline = Prefs.sessionStartedAt(ctx) + Prefs.limitMinutes(ctx) * 60_000L
        Prefs.setSession(ctx, deadline = deadline)
        scheduleDeadline(ctx)
        Log.i(TAG, "limit changed, deadline recalculated")
    }

    fun reset(ctx: Context) {
        AlarmScheduler.cancel(ctx)
        Prefs.setSession(ctx, sessionStartedAt = 0L, deadline = 0L, screenOffAt = 0L)
    }

    /** A session is running while the screen is on and unlocked. */
    fun isRunning(ctx: Context): Boolean {
        val start = Prefs.sessionStartedAt(ctx)
        return start in 1..now() && Prefs.screenOffAt(ctx) == 0L
    }

    fun elapsedMinutes(ctx: Context): Long {
        val start = Prefs.sessionStartedAt(ctx)
        if (start <= 0L) return 0L
        return ((now() - start) / 60_000L).coerceAtLeast(0L)
    }

    /** Elapsed-realtime value converted to epoch millis for the UI, null if unset. */
    fun toEpochMillis(elapsed: Long): Long? {
        if (elapsed <= 0L) return null
        return System.currentTimeMillis() - (now() - elapsed)
    }

    private fun scheduleDeadline(ctx: Context) {
        val deadline = Prefs.deadline(ctx)
        if (deadline <= 0L) {
            AlarmScheduler.cancel(ctx)
            return
        }
        // An overdue deadline (e.g. resumed within grace) fires right away.
        AlarmScheduler.scheduleAt(ctx, maxOf(deadline, now() + 1_000L))
    }
}
