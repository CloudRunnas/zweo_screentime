package com.cloudrunnas.screentime

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Receives the exact alarm when the screen time limit is reached. */
class LimitReachedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "alarm fired")
        if (!Prefs.isEnabled(context)) return
        if (!Session.isUserActive(context)) {
            Log.i(TAG, "phone not in use, warning skipped")
            return
        }
        Session.onWarningShown(context)
        Notifications.showWarning(context)
    }
}
