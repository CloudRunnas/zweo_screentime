package com.cloudrunnas.screentime

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Restarts monitoring after a reboot or an app update. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) return

        Log.i(TAG, "received $action")
        if (action != Intent.ACTION_MY_PACKAGE_REPLACED) {
            // elapsedRealtime restarts at boot, stored session timestamps are meaningless now.
            Session.reset(context)
        }
        if (!Prefs.isEnabled(context)) return
        try {
            ScreenTimeService.start(context)
        } catch (e: Exception) {
            Log.e(TAG, "could not start service from $action", e)
        }
    }
}
