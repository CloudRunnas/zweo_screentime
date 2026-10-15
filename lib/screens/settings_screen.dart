import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/screen_time_channel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  ScreenTimeSettings? _settings;
  int _limit = 15;
  int _snooze = 5;
  int _grace = 30;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _apply(await ScreenTimeChannel.getSettings());
    } on PlatformException catch (e) {
      _showSnack('Fehler beim Laden: ${e.message ?? e.code}');
    }
  }

  void _apply(ScreenTimeSettings settings) {
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _limit = settings.limitMinutes;
      _snooze = settings.snoozeMinutes;
      _grace = settings.graceSeconds;
      _titleController.text = settings.warningTitle;
      _textController.text = settings.warningText;
    });
  }

  Future<bool> _save({bool quiet = false}) async {
    setState(() => _saving = true);
    try {
      _apply(await ScreenTimeChannel.saveSettings(
        limitMinutes: _limit,
        snoozeMinutes: _snooze,
        graceSeconds: _grace,
        warningTitle: _titleController.text,
        warningText: _textController.text,
      ));
      if (!quiet) _showSnack('Gespeichert – das Limit gilt ab sofort');
      return true;
    } on PlatformException catch (e) {
      _showSnack('Fehler beim Speichern: ${e.message ?? e.code}');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _preview() async {
    if (!await _save(quiet: true)) return;
    try {
      await ScreenTimeChannel.previewWarning();
    } on PlatformException catch (e) {
      _showSnack('Vorschau fehlgeschlagen: ${e.message ?? e.code}');
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auf Standard zurücksetzen?'),
        content: const Text('Zeitlimit, Snooze, Kulanzzeit und Warnungstext werden zurückgesetzt.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Zurücksetzen')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      _apply(await ScreenTimeChannel.resetSettings());
      _showSnack('Einstellungen zurückgesetzt');
    } on PlatformException catch (e) {
      _showSnack('Fehler: ${e.message ?? e.code}');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        actions: [
          IconButton(
            tooltip: 'Auf Standard zurücksetzen',
            icon: const Icon(Icons.restore),
            onPressed: settings == null ? null : _reset,
          ),
        ],
      ),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _NumberSetting(
                  title: 'Zeitlimit',
                  description: 'Nach so vielen Minuten am Stück erscheint die Warnung.',
                  value: _limit,
                  min: ScreenTimeSettings.minLimitMinutes,
                  max: ScreenTimeSettings.maxLimitMinutes,
                  unit: 'min',
                  onChanged: (v) => setState(() => _limit = v),
                ),
                _NumberSetting(
                  title: 'Snooze-Dauer',
                  description: 'Abstand für „Noch X min“ und die erneute Erinnerung, '
                      'wenn die Warnung ignoriert wird.',
                  value: _snooze,
                  min: ScreenTimeSettings.minSnoozeMinutes,
                  max: ScreenTimeSettings.maxSnoozeMinutes,
                  unit: 'min',
                  onChanged: (v) => setState(() => _snooze = v),
                ),
                _NumberSetting(
                  title: 'Kulanzzeit',
                  description: 'Wird das Handy innerhalb dieser Zeit nach dem Sperren wieder '
                      'entsperrt, läuft die Sitzung weiter. 0 = aus.',
                  value: _grace,
                  min: ScreenTimeSettings.minGraceSeconds,
                  max: ScreenTimeSettings.maxGraceSeconds,
                  unit: 's',
                  onChanged: (v) => setState(() => _grace = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  maxLength: ScreenTimeSettings.maxTitleLength,
                  decoration: InputDecoration(
                    labelText: 'Titel der Warnung',
                    hintText: settings.defaultWarningTitle,
                    helperText: 'Leer = Standardtitel',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _textController,
                  maxLength: ScreenTimeSettings.maxTextLength,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Text der Warnung',
                    hintText: settings.defaultWarningText,
                    helperText: '{minutes} wird durch die Nutzungsdauer ersetzt. Leer = Standardtext',
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _preview,
                        icon: const Icon(Icons.visibility),
                        label: const Text('Vorschau'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : () => _save(),
                        icon: const Icon(Icons.save),
                        label: const Text('Speichern'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _NumberSetting extends StatelessWidget {
  const _NumberSetting({
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  final String title;
  final String description;
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = value.clamp(min, max);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              IconButton(
                onPressed: clamped > min ? () => onChanged(clamped - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '$clamped $unit',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: clamped < max ? () => onChanged(clamped + 1) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Slider(
            value: clamped.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$clamped $unit',
            onChanged: (v) => onChanged(v.round()),
          ),
          Text(description, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
