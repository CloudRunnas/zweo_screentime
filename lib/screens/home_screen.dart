import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/device_status_service.dart';
import '../services/screen_time_channel.dart';
import '../widgets/status_light.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  MonitoringStatus? _status;
  ScreenTimeSettings? _settings;
  List<DeviceCheck>? _checks;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final settings = await ScreenTimeChannel.getSettings();
      final checks = await DeviceStatusService.loadChecks();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _checks = checks;
      });
      await _loadStatus();
    } on PlatformException catch (e) {
      _showSnack('Fehler beim Laden: ${e.message ?? e.code}');
    }
  }

  Future<void> _loadStatus() async {
    try {
      final status = await ScreenTimeChannel.getStatus();
      if (!mounted) return;
      setState(() => _status = status);
    } on PlatformException catch (e) {
      _showSnack('Status nicht abrufbar: ${e.message ?? e.code}');
    }
  }

  Future<void> _toggleMonitoring(bool enable) async {
    setState(() => _busy = true);
    try {
      if (enable) {
        await ScreenTimeChannel.startMonitoring();
      } else {
        await ScreenTimeChannel.stopMonitoring();
      }
      // The service starts asynchronously; give it a moment before reading the status.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _loadStatus();
    } on PlatformException catch (e) {
      _showSnack('Fehler: ${e.message ?? e.code}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    await _load();
  }

  Future<void> _openSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SetupScreen(firstRun: false)),
    );
    await _load();
  }

  static String _time(DateTime? t) {
    if (t == null) return '–';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final settings = _settings;
    final checks = _checks;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('zweo_screentime'),
        actions: [
          IconButton(
            tooltip: 'Einstellungen',
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: status == null || settings == null || checks == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: SwitchListTile(
                      title: const Text('Überwachung aktiv'),
                      subtitle: Text('Warnung nach ${settings.limitMinutes} min am Stück'),
                      value: status.enabled,
                      onChanged: _busy ? null : _toggleMonitoring,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ExactAlarmCard(checks: checks),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          _row('Dienst', _serviceText(status)),
                          _row('Sitzung seit', _time(status.sessionStartedAt)),
                          _row(
                            'Warnung um',
                            status.warningDismissed
                                ? 'bestätigt, erst nach erneutem Entsperren'
                                : _time(status.nextWarningAt),
                          ),
                          _row('Snooze', '${settings.snoozeMinutes} min'),
                          _row(
                            'Kulanzzeit',
                            settings.graceSeconds == 0 ? 'aus' : '${settings.graceSeconds} s',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SetupSummaryCard(checks: checks, onTap: _openSetup),
                ],
              ),
            ),
    );
  }

  static String _serviceText(MonitoringStatus status) {
    if (!status.enabled) return 'aus';
    return status.serviceRunning ? 'läuft' : 'aktiviert, aber nicht gestartet';
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(label)),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _ExactAlarmCard extends StatelessWidget {
  const _ExactAlarmCard({required this.checks});

  final List<DeviceCheck> checks;

  @override
  Widget build(BuildContext context) {
    final check = checks.firstWhere((c) => c.id == CheckId.exactAlarms);
    final ok = check.level == CheckLevel.ok;
    final color = checkLevelColor(check.level);
    return Card(
      color: color.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: ListTile(
        leading: StatusLight(check.level),
        title: Text(ok ? 'Exakte Alarme erlaubt' : 'Exakte Alarme nicht erlaubt'),
        subtitle: Text(check.description),
        trailing: check.action == null
            ? null
            : TextButton(onPressed: check.action, child: const Text('Öffnen')),
      ),
    );
  }
}

class _SetupSummaryCard extends StatelessWidget {
  const _SetupSummaryCard({required this.checks, required this.onTap});

  final List<DeviceCheck> checks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final worst = checks.any((c) => c.level == CheckLevel.error)
        ? CheckLevel.error
        : checks.any((c) => c.level == CheckLevel.warn)
            ? CheckLevel.warn
            : CheckLevel.ok;
    final okCount = checks.where((c) => c.level == CheckLevel.ok).length;
    return Card(
      child: ListTile(
        leading: StatusLight(worst),
        title: const Text('Einrichtung'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$okCount von ${checks.length} Punkten in Ordnung'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [for (final c in checks) StatusLight(c.level, size: 18)],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
