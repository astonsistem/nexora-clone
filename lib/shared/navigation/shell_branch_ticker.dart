import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellBranchTicker extends StatelessWidget {
  const ShellBranchTicker({
    super.key,
    required this.branchIndex,
    required this.child,
  });

  final int branchIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shell = context.findAncestorWidgetOfExactType<StatefulNavigationShell>();
    final active = shell == null || shell.currentIndex == branchIndex;
    return TickerMode(
      enabled: active,
      child: child,
    );
  }
}
