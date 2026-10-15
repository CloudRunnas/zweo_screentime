import 'package:url_launcher/url_launcher.dart';

import 'screen_time_channel.dart';
import 'setup_store.dart';

enum CheckLevel { ok, warn, error }

enum CheckId { notifications, exactAlarms, overlay, fullScreen, battery, hibernation, autostart }

class DeviceCheck {
  const DeviceCheck({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    this.actionLabel,
    this.action,
    this.helpUrl,
    this.acknowledged,
  });

  final CheckId id;
  final String title;
  final String description;
  final CheckLevel level;
  final String? actionLabel;
  final Future<void> Function()? action;

  /// Link with more information (dontkillmyapp.com for OEM settings).
  final Uri? helpUrl;

  /// Non-null for checks that cannot be verified and need a manual confirmation.
  final bool? acknowledged;
}

class _Oem {
  const _Oem(this.name, this.slug, this.steps);

  final String name;
  final String slug;
  final String steps;
}

/// Collects all device settings the app depends on, depending on Android version and OEM.
class DeviceStatusService {
  static const _oems = <String, _Oem>{
    'xiaomi': _Oem(
      'Xiaomi',
      'xiaomi',
      'Sicherheit → Berechtigungen → Autostart: App aktivieren. '
          'Zusätzlich App-Info → Akkusparmodus → „Keine Einschränkungen“.',
    ),
    'huawei': _Oem(
      'Huawei',
      'huawei',
      'Einstellungen → Akku → App-Start: App auf „Manuell verwalten“ stellen '
          'und alle drei Schalter (Autostart, Sekundärstart, Im Hintergrund ausführen) aktivieren.',
    ),
    'honor': _Oem(
      'Honor',
      'huawei',
      'Einstellungen → Akku → App-Start: App auf „Manuell verwalten“ stellen '
          'und alle Schalter aktivieren.',
    ),
    'oppo': _Oem(
      'Oppo',
      'oppo',
      'App-Info → Akkunutzung: „Hintergrundaktivität erlauben“ und „Automatischer Start“ aktivieren.',
    ),
    'realme': _Oem(
      'Realme',
      'realme',
      'App-Info → Akkunutzung: „Hintergrundaktivität erlauben“ und „Automatischer Start“ aktivieren.',
    ),
    'oneplus': _Oem(
      'OnePlus',
      'oneplus',
      'App-Info → Akku: „Hintergrundaktivität erlauben“ bzw. Autostart aktivieren.',
    ),
    'vivo': _Oem(
      'Vivo',
      'vivo',
      'i Manager → App-Manager → Autostart-Manager: App erlauben. '
          'Akku → Hintergrund-Energieverbrauch: App erlauben.',
    ),
    'samsung': _Oem(
      'Samsung',
      'samsung',
      'Einstellungen → Akku → Hintergrundnutzungslimits: App aus „Schlafende Apps“ '
          'und „Tief schlafende Apps“ entfernen und zu „Nie schlafende Apps“ hinzufügen.',
    ),
    'asus': _Oem(
      'Asus',
      'asus',
      'Mobile Manager → Autostart-Manager: App erlauben.',
    ),
    'meizu': _Oem(
      'Meizu',
      'meizu',
      'Sicherheit → Berechtigungen → Hintergrundverwaltung: „Im Hintergrund laufen lassen“.',
    ),
  };

  static _Oem? _oemFor(String manufacturer) {
    final m = manufacturer.toLowerCase();
    if (m.contains('redmi') || m.contains('poco')) return _oems['xiaomi'];
    for (final entry in _oems.entries) {
      if (m.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static Future<List<DeviceCheck>> loadChecks() async {
    final device = await ScreenTimeChannel.getDeviceInfo();
    final sdk = device.sdkInt;
    final checks = <DeviceCheck>[];

    final notificationsOk = await ScreenTimeChannel.areNotificationsEnabled();
    checks.add(DeviceCheck(
      id: CheckId.notifications,
      title: 'Benachrichtigungen',
      description: 'Nötig für die Daueranzeige der Überwachung und die Warnung als Banner.',
      level: notificationsOk ? CheckLevel.ok : CheckLevel.error,
      actionLabel: notificationsOk ? null : 'Erlauben',
      action: notificationsOk ? null : ScreenTimeChannel.requestNotificationPermission,
    ));

    final exactOk = await ScreenTimeChannel.canScheduleExactAlarms();
    checks.add(DeviceCheck(
      id: CheckId.exactAlarms,
      title: 'Exakte Alarme',
      description: exactOk
          ? 'Die Warnung kommt auf die Sekunde genau.'
          : 'Ohne diese Berechtigung kann die Warnung mehrere Minuten zu spät kommen.',
      level: exactOk ? CheckLevel.ok : CheckLevel.error,
      actionLabel: exactOk || sdk < 31 ? null : 'Einstellung öffnen',
      action: exactOk || sdk < 31 ? null : ScreenTimeChannel.openExactAlarmSettings,
    ));

    final overlayOk = await ScreenTimeChannel.canDrawOverlays();
    checks.add(DeviceCheck(
      id: CheckId.overlay,
      title: 'Über anderen Apps einblenden',
      description: overlayOk
          ? 'Die Warnung erscheint als Vollbild über der gerade genutzten App.'
          : 'Ohne diese Erlaubnis erscheint statt des Vollbilds nur ein Banner oben am Bildschirm.',
      level: overlayOk ? CheckLevel.ok : CheckLevel.error,
      actionLabel: overlayOk ? null : 'Einstellung öffnen',
      action: overlayOk ? null : ScreenTimeChannel.openOverlaySettings,
    ));

    if (sdk >= 34) {
      final fullScreenOk = await ScreenTimeChannel.canUseFullScreenIntent();
      checks.add(DeviceCheck(
        id: CheckId.fullScreen,
        title: 'Vollbild-Benachrichtigungen',
        description: 'Ersatzweg, falls das Einblenden über anderen Apps nicht klappt.',
        level: fullScreenOk ? CheckLevel.ok : CheckLevel.warn,
        actionLabel: fullScreenOk ? null : 'Einstellung öffnen',
        action: fullScreenOk ? null : ScreenTimeChannel.openFullScreenIntentSettings,
      ));
    }

    final batteryOk = await ScreenTimeChannel.isIgnoringBatteryOptimizations();
    checks.add(DeviceCheck(
      id: CheckId.battery,
      title: 'Akku-Optimierung',
      description: batteryOk
          ? 'Die App ist von der Akku-Optimierung ausgenommen.'
          : 'Ohne Ausnahme kann Android die Überwachung im Hintergrund beenden. '
              'Der Mehrverbrauch ist sehr gering.',
      level: batteryOk ? CheckLevel.ok : CheckLevel.error,
      actionLabel: batteryOk ? null : 'Ausnahme erlauben',
      action: batteryOk ? null : ScreenTimeChannel.requestIgnoreBatteryOptimizations,
    ));

    final hibernation = await ScreenTimeChannel.getHibernationStatus();
    if (hibernation != HibernationStatus.notApplicable) {
      final ok = hibernation == HibernationStatus.ok;
      checks.add(DeviceCheck(
        id: CheckId.hibernation,
        title: 'App-Ruhezustand',
        description: ok
            ? '„App-Aktivität pausieren, wenn nicht verwendet“ ist ausgeschaltet.'
            : 'Schalte „App-Aktivität pausieren, wenn nicht verwendet“ in der App-Info aus, '
                'sonst pausiert Android die App, wenn sie lange nicht geöffnet wurde.',
        level: ok ? CheckLevel.ok : CheckLevel.warn,
        actionLabel: ok ? null : 'App-Info öffnen',
        action: ok ? null : ScreenTimeChannel.openHibernationSettings,
      ));
    }

    final oem = _oemFor(device.manufacturer);
    if (oem != null) {
      final acknowledged = await SetupStore.isAutostartAcknowledged();
      checks.add(DeviceCheck(
        id: CheckId.autostart,
        title: 'Autostart (${oem.name})',
        description: '${oem.steps}\n'
            'Diese Einstellung kann die App nicht selbst prüfen. Hake sie ab, wenn du sie gesetzt hast.',
        level: acknowledged ? CheckLevel.ok : CheckLevel.warn,
        actionLabel: 'Einstellung öffnen',
        action: () async {
          await ScreenTimeChannel.openAutostartSettings();
        },
        helpUrl: Uri.parse('https://dontkillmyapp.com/${oem.slug}'),
        acknowledged: acknowledged,
      ));
    }

    return checks;
  }

  static Future<void> openHelp(Uri url) async {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
