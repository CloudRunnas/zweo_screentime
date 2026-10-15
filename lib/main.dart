import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/limit_screen.dart';
import 'screens/setup_screen.dart';
import 'services/setup_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The native LimitActivity starts its own engine with the initial route "/limit".
  if (PlatformDispatcher.instance.defaultRouteName == '/limit') {
    runApp(const _App(home: LimitScreen()));
    return;
  }

  final setupCompleted = await SetupStore.isSetupCompleted();
  runApp(_App(
    home: setupCompleted ? const HomeScreen() : const SetupScreen(firstRun: true),
  ));
}

ThemeData _theme(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: brightness),
      useMaterial3: true,
    );

class _App extends StatelessWidget {
  const _App({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Zweos Screentime',
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        // Ignore the platform route ("/limit"); the home widget is chosen in main().
        initialRoute: '/',
        home: home,
      );
}
