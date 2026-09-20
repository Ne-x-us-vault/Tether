import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Root application widget.
///
/// Composes material design with the app's [GoRouter] instance. All app state
/// (router, services, prefs) is wired up in `main.dart` and injected here, so
/// `LovitApp` stays a pure view of configuration.
class LovitApp extends StatelessWidget {
  const LovitApp({super.key, required this.routerConfig});

  final GoRouter routerConfig;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Lovit',
      debugShowCheckedModeBanner: false,
      routerConfig: routerConfig,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF09080E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFC9BFFF),
          secondary: Color(0xFFFF9BAB),
          surface: Color(0xFF131318),
          onPrimary: Color(0xFF1A1530),
          onSecondary: Colors.white,
          onSurface: Color(0xFFF2EFF9),
        ),
        useMaterial3: true,
      ),
    );
  }
}
