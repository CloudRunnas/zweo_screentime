import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/screen_time_channel.dart';

/// Full-screen warning shown by the native LimitActivity (route "/limit").
class LimitScreen extends StatefulWidget {
  const LimitScreen({super.key});

  @override
  State<LimitScreen> createState() => _LimitScreenState();
}

class _LimitScreenState extends State<LimitScreen> with WidgetsBindingObserver {
  WarningInfo? _warning;
  bool _busy = false;

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
      final warning = await ScreenTimeChannel.getWarning();
      if (mounted) setState(() => _warning = warning);
    } on PlatformException {
      if (mounted) {
        setState(() => _warning = const WarningInfo(
              title: 'Bildschirmzeit erreicht',
              text: 'Zeit für eine Pause!',
              snoozeMinutes: 5,
              preview: false,
            ));
      }
    }
  }

  Future<void> _close(Future<void> Function()? action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (action != null && _warning?.preview != true) await action();
    } on PlatformException {
      // Closing must always work, even if the native call failed.
    }
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final warning = _warning;
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.colorScheme.errorContainer,
        body: SafeArea(
          child: warning == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (warning.preview)
                        Text(
                          'Vorschau',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge,
                        ),
                      const Spacer(),
                      Icon(Icons.hourglass_bottom, size: 96, color: theme.colorScheme.onErrorContainer),
                      const SizedBox(height: 24),
                      Text(
                        warning.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        warning.text,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _busy ? null : () => _close(ScreenTimeChannel.acknowledgeWarning),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                        child: const Text('Verstanden'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _busy ? null : () => _close(ScreenTimeChannel.snooze),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                        child: Text('Noch ${warning.snoozeMinutes} min'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
