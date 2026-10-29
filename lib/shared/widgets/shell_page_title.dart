import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/router/home_router.dart';

class ShellPageTitle extends StatelessWidget {
  const ShellPageTitle({
    super.key,
    required this.title,
    this.showHomeButton = true,
  });

  final String title;
  final bool showHomeButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ),
        if (showHomeButton)
          IconButton(
            onPressed: () => context.go(HomeRouter.home),
            tooltip: 'Beranda',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              highlightColor: Colors.white24,
            ),
            icon: const Icon(Icons.home_rounded, size: 26),
          ),
      ],
    );
  }
}
