import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/device_status_service.dart';
import '../services/setup_store.dart';
import '../widgets/status_light.dart';
import 'home_screen.dart';

/// First-run setup: shows every required device setting with a traffic light and
/// opens the matching settings page. Re-checks whenever the user returns to the app.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.firstRun});

  final bool firstRun;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  List<DeviceCheck>? _checks;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final checks = await DeviceStatusService.loadChecks();
      if (!mounted) return;
      setState(() {
        _checks = checks;
        _error = null;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? e.code);
    }
  }

  Future<void> _runAction(DeviceCheck check) async {
    try {
      await check.action?.call();
    } on PlatformException catch (e) {
      _showSnack('Konnte Einstellung nicht öffnen: ${e.message ?? e.code}');
    }
    await _load();
  }

  Future<void> _setAcknowledged(DeviceCheck check, bool value) async {
    await check.onAcknowledged?.call(value);
    await _load();
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _finish() async {
    final open = _checks?.where((c) => c.level == CheckLevel.error).toList() ?? [];
    if (open.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Noch nicht alles eingerichtet'),
          content: Text(
            'Folgende Punkte fehlen noch:\n\n'
            '${open.map((c) => '• ${c.title}').join('\n')}\n\n'
            'Ohne sie kann die Warnung zu spät, gar nicht oder nur als Banner kommen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Zurück'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Trotzdem fertig'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    await SetupStore.setSetupCompleted(true);
    if (!mounted) return;
    if (widget.firstRun) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final checks = _checks;
    return Scaffold(
      appBar: AppBar(title: const Text('Einrichtung')),
      body: _error != null
          ? Center(child: Text('Fehler beim Prüfen: $_error'))
          : checks == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Damit die Bildschirmzeit-Warnung zuverlässig und pünktlich kommt, '
                        'braucht die App ein paar Einstellungen. Tippe auf die Buttons, '
                        'um die passende Seite zu öffnen; danach aktualisiert sich der Status.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      for (final check in checks) _CheckCard(
                        check: check,
                        onAction: () => _runAction(check),
                        onAcknowledged: (value) => _setAcknowledged(check, value),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: checks == null ? null : _finish,
            child: Text(widget.firstRun ? 'Fertig' : 'Schließen'),
          ),
        ),
      ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({
    required this.check,
    required this.onAction,
    required this.onAcknowledged,
  });

  final DeviceCheck check;
  final VoidCallback onAction;
  final ValueChanged<bool> onAcknowledged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final helpUrl = check.helpUrl;
    final acknowledged = check.acknowledged;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: checkLevelColor(check.level), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusLight(check.level),
                const SizedBox(width: 12),
                Expanded(child: Text(check.title, style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text(check.description, style: theme.textTheme.bodyMedium),
            if (acknowledged != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: acknowledged,
                onChanged: (value) => onAcknowledged(value ?? false),
                title: const Text('Erledigt'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            if (check.actionLabel != null || helpUrl != null)
              Wrap(
                spacing: 8,
                children: [
                  if (check.actionLabel != null)
                    FilledButton.tonal(onPressed: onAction, child: Text(check.actionLabel!)),
                  if (helpUrl != null)
                    TextButton(
                      onPressed: () => DeviceStatusService.openHelp(helpUrl),
                      child: const Text('Mehr Infos'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
