package com.cloudrunnas.screentime

import android.app.KeyguardManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * Foreground service that keeps the process alive so the screen broadcasts
 * (USER_PRESENT, SCREEN_ON, SCREEN_OFF) can be received. They cannot be declared in the manifest.
 */
class ScreenTimeService : Service() {
    companion object {
        @Volatile
        var isRunning = false
            private set

        fun start(ctx: Context) {
            ContextCompat.startForegroundService(ctx, Intent(ctx, ScreenTimeService::class.java))
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, ScreenTimeService::class.java))
        }
    }

    private var receiverRegistered = false

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_USER_PRESENT -> {
                    Log.i(TAG, "user present (unlocked)")
                    Session.onUserActive(context)
                }
                Intent.ACTION_SCREEN_ON -> {
                    // Devices without a lock screen send no USER_PRESENT.
                    val keyguard = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                    if (!keyguard.isKeyguardLocked) {
                        Log.i(TAG, "screen on without keyguard")
                        Session.onUserActive(context)
                    }
                }
                Intent.ACTION_SCREEN_OFF -> Session.onScreenOff(context)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        Notifications.ensureChannels(this)
        try {
            ServiceCompat.startForeground(
                this,
                Notifications.ID_SERVICE,
                Notifications.serviceNotification(this),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                } else {
                    0
                },
            )
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
            stopSelf()
            return
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_USER_PRESENT)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        // System broadcasts are delivered to non-exported receivers as well.
        ContextCompat.registerReceiver(this, screenReceiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        receiverRegistered = true
        isRunning = true
        Log.i(TAG, "service started")

        if (Session.isUserActive(this)) {
            Session.onUserActive(this)
        } else {
            Session.onScreenOff(this)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!Prefs.isEnabled(this) || !isRunning) {
            Log.i(TAG, "monitoring disabled or not in foreground, stopping service")
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onDestroy() {
        if (receiverRegistered) {
            unregisterReceiver(screenReceiver)
            receiverRegistered = false
        }
        isRunning = false
        AlarmScheduler.cancel(this)
        Log.i(TAG, "service stopped")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
