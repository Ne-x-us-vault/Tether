import 'package:flutter/material.dart';
import 'lovit_theme.dart';

class LovitScaffold extends StatelessWidget {
  const LovitScaffold({
    super.key,
    required this.child,
    this.bottomNavigationBar,
  });

  final Widget child;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LovitColors.background,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(child: child),
    );
  }
}