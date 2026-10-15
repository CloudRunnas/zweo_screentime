# zweo_screentime

Android-App (Flutter + nativer Kotlin-Dienst), die die **zusammenhängende Bildschirmzeit** begrenzt – komplett offline.

- Beim **Entsperren** startet ein exakter Alarm mit dem eingestellten Zeitlimit.
- Geht der **Bildschirm aus**, wird der Alarm abgebrochen. Wird innerhalb der **Kulanzzeit** wieder entsperrt, läuft die Sitzung weiter.
- **Intervall-Timer:** Ist das Limit erreicht, erscheint eine **Vollbild-Warnung** mit eigenem Titel/Text (`{minutes}` = Nutzungsdauer). „Verstanden“ startet das nächste Intervall (z. B. alle 20 min eine Bildschirmpause), „Noch X min“ verschiebt die Warnung, eine ignorierte Warnung kommt nach der Snooze-Dauer erneut.
- Eine **Ersteinrichtung** prüft alle nötigen Geräte-Einstellungen (Ampel) und öffnet die passende Einstellungsseite – inkl. Xiaomi „Sonstige Berechtigungen“.

## Architektur

| Teil | Ort |
|---|---|
| Foreground Service (`specialUse`), registriert `USER_PRESENT` / `SCREEN_ON` / `SCREEN_OFF` | `android/app/src/main/kotlin/com/cloudrunnas/screentime/ScreenTimeService.kt` |
| Sitzungslogik (Deadline, Kulanz, Snooze) | `Session.kt` |
| Exakte Alarme (`setExactAndAllowWhileIdle`, `ELAPSED_REALTIME_WAKEUP`) | `AlarmScheduler.kt` |
| Warnung (Overlay-Start der `LimitActivity`, sonst Full-Screen-Notification) | `Notifications.kt`, `LimitReachedReceiver.kt`, `LimitActivity.kt` |
| Neustart nach Boot / Update | `BootReceiver.kt` |
| MethodChannel `screen_time/control` | `ScreenTimeChannel.kt` ↔ `lib/services/screen_time_channel.dart` |
| UI | `lib/screens/` |

Debuggen: `adb logcat -s ScreenTime`, Alarme prüfen: `adb shell dumpsys alarm | grep -A3 com.cloudrunnas.screentime`.

## Build

Gebaut wird ausschließlich per GitHub Actions (`.github/workflows/build-apk.yml`, Flutter 3.44.1). Jeder Push erzeugt ein Release `build-<Nr>` mit je einer APK für `arm64-v8a`, `armeabi-v7a` und `x86_64`.

Signiert wird mit einem Release-Keystore aus den Repo-Secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. Ohne diesen Keystore lassen sich Updates nicht über eine installierte Version installieren.
