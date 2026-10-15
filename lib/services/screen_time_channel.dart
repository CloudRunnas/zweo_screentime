import 'package:flutter/services.dart';

/// Settings stored natively (source of truth for the background service).
class ScreenTimeSettings {
  const ScreenTimeSettings({
    required this.limitMinutes,
    required this.snoozeMinutes,
    required this.graceSeconds,
    required this.warningTitle,
    required this.warningText,
    required this.defaultWarningTitle,
    required this.defaultWarningText,
  });

  static const minLimitMinutes = 1;
  static const maxLimitMinutes = 240;
  static const minSnoozeMinutes = 1;
  static const maxSnoozeMinutes = 60;
  static const minGraceSeconds = 0;
  static const maxGraceSeconds = 120;
  static const maxTitleLength = 60;
  static const maxTextLength = 300;

  final int limitMinutes;
  final int snoozeMinutes;
  final int graceSeconds;

  /// Raw values; empty means the default text is used.
  final String warningTitle;
  final String warningText;
  final String defaultWarningTitle;
  final String defaultWarningText;

  factory ScreenTimeSettings.fromMap(Map<String, dynamic> map) => ScreenTimeSettings(
        limitMinutes: map['limitMinutes'] as int,
        snoozeMinutes: map['snoozeMinutes'] as int,
        graceSeconds: map['graceSeconds'] as int,
        warningTitle: map['warningTitle'] as String,
        warningText: map['warningText'] as String,
        defaultWarningTitle: map['defaultWarningTitle'] as String,
        defaultWarningText: map['defaultWarningText'] as String,
      );
}

class MonitoringStatus {
  const MonitoringStatus({
    required this.enabled,
    required this.serviceRunning,
    required this.sessionStartedAt,
    required this.nextWarningAt,
  });

  final bool enabled;
  final bool serviceRunning;
  final DateTime? sessionStartedAt;
  final DateTime? nextWarningAt;

  factory MonitoringStatus.fromMap(Map<String, dynamic> map) => MonitoringStatus(
        enabled: map['enabled'] as bool,
        serviceRunning: map['serviceRunning'] as bool,
        sessionStartedAt: _date(map['sessionStartedAt']),
        nextWarningAt: _date(map['nextWarningAt']),
      );

  static DateTime? _date(Object? millis) =>
      millis is int ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
}

class WarningInfo {
  const WarningInfo({
    required this.title,
    required this.text,
    required this.snoozeMinutes,
    required this.preview,
  });

  final String title;
  final String text;
  final int snoozeMinutes;
  final bool preview;

  factory WarningInfo.fromMap(Map<String, dynamic> map) => WarningInfo(
        title: map['title'] as String,
        text: map['text'] as String,
        snoozeMinutes: map['snoozeMinutes'] as int,
        preview: map['preview'] as bool,
      );
}

class DeviceInfo {
  const DeviceInfo({required this.manufacturer, required this.sdkInt});

  final String manufacturer;
  final int sdkInt;
}

enum HibernationStatus { ok, restricted, notApplicable }

/// Typed wrapper for the native MethodChannel "screen_time/control".
class ScreenTimeChannel {
  static const _channel = MethodChannel('screen_time/control');

  static Future<Map<String, dynamic>> _map(String method, [Map<String, Object?>? args]) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(method, args);
    if (result == null) {
      throw PlatformException(code: 'NULL_RESULT', message: '$method returned null');
    }
    return result;
  }

  static Future<bool> _bool(String method) async =>
      await _channel.invokeMethod<bool>(method) ?? false;

  // Settings
  static Future<ScreenTimeSettings> getSettings() async =>
      ScreenTimeSettings.fromMap(await _map('getSettings'));

  static Future<ScreenTimeSettings> saveSettings({
    required int limitMinutes,
    required int snoozeMinutes,
    required int graceSeconds,
    required String warningTitle,
    required String warningText,
  }) async =>
      ScreenTimeSettings.fromMap(await _map('saveSettings', {
        'limitMinutes': limitMinutes,
        'snoozeMinutes': snoozeMinutes,
        'graceSeconds': graceSeconds,
        'warningTitle': warningTitle,
        'warningText': warningText,
      }));

  static Future<ScreenTimeSettings> resetSettings() async =>
      ScreenTimeSettings.fromMap(await _map('resetSettings'));

  // Monitoring
  static Future<void> startMonitoring() => _channel.invokeMethod<void>('startMonitoring');
  static Future<void> stopMonitoring() => _channel.invokeMethod<void>('stopMonitoring');
  static Future<MonitoringStatus> getStatus() async =>
      MonitoringStatus.fromMap(await _map('getStatus'));

  // Warning screen
  static Future<WarningInfo> getWarning() async => WarningInfo.fromMap(await _map('getWarning'));
  static Future<void> snooze() => _channel.invokeMethod<void>('snooze');
  /// "Verstanden": restarts the interval timer.
  static Future<void> acknowledgeWarning() => _channel.invokeMethod<void>('acknowledgeWarning');
  static Future<void> previewWarning() => _channel.invokeMethod<void>('previewWarning');

  // Device checks
  static Future<DeviceInfo> getDeviceInfo() async {
    final map = await _map('getDeviceInfo');
    return DeviceInfo(
      manufacturer: map['manufacturer'] as String,
      sdkInt: map['sdkInt'] as int,
    );
  }

  static Future<bool> areNotificationsEnabled() => _bool('areNotificationsEnabled');
  static Future<bool> openNotificationSettings() => _bool('openNotificationSettings');

  /// First call shows the system dialog (Android 13+), later calls open the settings page.
  static Future<bool> requestNotificationPermission() => _bool('requestNotificationPermission');
  static Future<bool> canScheduleExactAlarms() => _bool('canScheduleExactAlarms');
  static Future<bool> openExactAlarmSettings() => _bool('openExactAlarmSettings');
  static Future<bool> canDrawOverlays() => _bool('canDrawOverlays');
  static Future<bool> openOverlaySettings() => _bool('openOverlaySettings');
  static Future<bool> canUseFullScreenIntent() => _bool('canUseFullScreenIntent');
  static Future<bool> openFullScreenIntentSettings() => _bool('openFullScreenIntentSettings');
  static Future<bool> isIgnoringBatteryOptimizations() => _bool('isIgnoringBatteryOptimizations');
  static Future<bool> requestIgnoreBatteryOptimizations() =>
      _bool('requestIgnoreBatteryOptimizations');
  static Future<bool> openHibernationSettings() => _bool('openHibernationSettings');
  static Future<bool> openAppDetails() => _bool('openAppDetails');

  static Future<HibernationStatus> getHibernationStatus() async {
    final value = await _channel.invokeMethod<String>('getHibernationStatus');
    return switch (value) {
      'ok' => HibernationStatus.ok,
      'restricted' => HibernationStatus.restricted,
      _ => HibernationStatus.notApplicable,
    };
  }

  /// Xiaomi "Sonstige Berechtigungen": true/false if readable, null if the ROM hides it.
  static Future<bool?> getMiuiOtherPermissionsStatus() =>
      _channel.invokeMethod<bool>('getMiuiOtherPermissionsStatus');
  static Future<bool> openMiuiOtherPermissions() => _bool('openMiuiOtherPermissions');

  /// Returns true if an OEM autostart page was opened, false for the app details fallback.
  static Future<bool> openAutostartSettings() async =>
      await _channel.invokeMethod<String>('openAutostartSettings') == 'autostart';
}
