import 'package:flutter/material.dart';

/// Bare home screen — deliberately empty; reserved for future content.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.onOpenChat,
    this.onOpenBudget,
    this.onOpenCalendar,
    this.onOpenMaps,
  });

  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenBudget;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenMaps;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(),
    );
  }
}