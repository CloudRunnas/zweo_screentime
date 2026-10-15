package com.cloudrunnas.screentime

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** Full-screen warning. Runs its own Flutter engine that starts with the route "/limit". */
class LimitActivity : FlutterActivity() {
    override fun getInitialRoute(): String = "/limit"

    // singleTask: a second warning (or preview) reuses this instance; keep getIntent() current
    // so the channel reports the right preview flag.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ScreenTimeChannel.register(flutterEngine, this)
    }
}
