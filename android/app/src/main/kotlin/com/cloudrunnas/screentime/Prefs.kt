package com.cloudrunnas.screentime

import android.content.Context
import android.content.SharedPreferences

const val TAG = "ScreenTime"

/**
 * Native settings and session state. Single source of truth for the background service.
 * All timestamps are SystemClock.elapsedRealtime() values (immune to wall clock changes).
 */
object Prefs {
    private const val FILE = "screen_time"

    const val DEFAULT_LIMIT_MINUTES = 15
    const val DEFAULT_SNOOZE_MINUTES = 5
    const val DEFAULT_GRACE_SECONDS = 30
    const val DEFAULT_WARNING_TITLE = "Bildschirmzeit erreicht"
    const val DEFAULT_WARNING_TEXT = "Du bist seit {minutes} Minuten am Handy. Zeit für eine Pause!"

    const val MIN_LIMIT_MINUTES = 1
    const val MAX_LIMIT_MINUTES = 240
    const val MIN_SNOOZE_MINUTES = 1
    const val MAX_SNOOZE_MINUTES = 60
    const val MIN_GRACE_SECONDS = 0
    const val MAX_GRACE_SECONDS = 120
    const val MAX_TITLE_LENGTH = 60
    const val MAX_TEXT_LENGTH = 300

    private const val KEY_ENABLED = "enabled"
    private const val KEY_LIMIT = "limitMinutes"
    private const val KEY_SNOOZE = "snoozeMinutes"
    private const val KEY_GRACE = "graceSeconds"
    private const val KEY_TITLE = "warningTitle"
    private const val KEY_TEXT = "warningText"
    private const val KEY_SESSION_START = "sessionStartedAt"
    private const val KEY_DEADLINE = "deadline"
    private const val KEY_SCREEN_OFF = "screenOffAt"

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun isEnabled(ctx: Context) = prefs(ctx).getBoolean(KEY_ENABLED, false)
    fun setEnabled(ctx: Context, value: Boolean) = prefs(ctx).edit().putBoolean(KEY_ENABLED, value).apply()

    fun limitMinutes(ctx: Context) = prefs(ctx).getInt(KEY_LIMIT, DEFAULT_LIMIT_MINUTES)
    fun snoozeMinutes(ctx: Context) = prefs(ctx).getInt(KEY_SNOOZE, DEFAULT_SNOOZE_MINUTES)
    fun graceSeconds(ctx: Context) = prefs(ctx).getInt(KEY_GRACE, DEFAULT_GRACE_SECONDS)

    /** Stored value may be blank; then the default is used. */
    fun warningTitle(ctx: Context): String =
        prefs(ctx).getString(KEY_TITLE, null)?.takeIf { it.isNotBlank() } ?: DEFAULT_WARNING_TITLE

    fun warningText(ctx: Context): String =
        prefs(ctx).getString(KEY_TEXT, null)?.takeIf { it.isNotBlank() } ?: DEFAULT_WARNING_TEXT

    fun rawWarningTitle(ctx: Context): String = prefs(ctx).getString(KEY_TITLE, null) ?: ""
    fun rawWarningText(ctx: Context): String = prefs(ctx).getString(KEY_TEXT, null) ?: ""

    fun saveSettings(
        ctx: Context,
        limitMinutes: Int,
        snoozeMinutes: Int,
        graceSeconds: Int,
        warningTitle: String,
        warningText: String,
    ) {
        prefs(ctx).edit()
            .putInt(KEY_LIMIT, limitMinutes.coerceIn(MIN_LIMIT_MINUTES, MAX_LIMIT_MINUTES))
            .putInt(KEY_SNOOZE, snoozeMinutes.coerceIn(MIN_SNOOZE_MINUTES, MAX_SNOOZE_MINUTES))
            .putInt(KEY_GRACE, graceSeconds.coerceIn(MIN_GRACE_SECONDS, MAX_GRACE_SECONDS))
            .putString(KEY_TITLE, warningTitle.trim().take(MAX_TITLE_LENGTH))
            .putString(KEY_TEXT, warningText.trim().take(MAX_TEXT_LENGTH))
            .apply()
    }

    fun resetSettings(ctx: Context) {
        prefs(ctx).edit()
            .remove(KEY_LIMIT)
            .remove(KEY_SNOOZE)
            .remove(KEY_GRACE)
            .remove(KEY_TITLE)
            .remove(KEY_TEXT)
            .apply()
    }

    fun formatWarningText(ctx: Context, minutes: Long): String =
        warningText(ctx).replace("{minutes}", minutes.toString())

    // Session state (elapsedRealtime millis, 0 = unset). commit() so a following read in
    // another component (receiver, service) always sees the new value.
    fun sessionStartedAt(ctx: Context) = prefs(ctx).getLong(KEY_SESSION_START, 0L)
    fun deadline(ctx: Context) = prefs(ctx).getLong(KEY_DEADLINE, 0L)
    fun screenOffAt(ctx: Context) = prefs(ctx).getLong(KEY_SCREEN_OFF, 0L)

    fun setSession(
        ctx: Context,
        sessionStartedAt: Long = Prefs.sessionStartedAt(ctx),
        deadline: Long = Prefs.deadline(ctx),
        screenOffAt: Long = Prefs.screenOffAt(ctx),
    ) {
        prefs(ctx).edit()
            .putLong(KEY_SESSION_START, sessionStartedAt)
            .putLong(KEY_DEADLINE, deadline)
            .putLong(KEY_SCREEN_OFF, screenOffAt)
            .commit()
    }
}
