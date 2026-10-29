import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/faq/presentation/faq_page.dart';
import '../features/faq/router/faq_router.dart';
import '../features/home/presentation/home_page.dart';
import '../features/home/router/home_router.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/profile/router/profile_router.dart';
import '../features/recap/presentation/recap_page.dart';
import '../features/recap/router/recap_router.dart';
import '../shared/navigation/main_shell.dart';
import '../shared/navigation/shell_branch_ticker.dart';

class ShellRouter {
  static StatefulShellRoute get shellRoute => StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: HomeRouter.home,
                builder: (context, state) => const ShellBranchTicker(
                  branchIndex: 0,
                  child: HomePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RecapRouter.recap,
                builder: (context, state) {
                  final tab = state.uri.queryParameters['tab'];
                  final initialTab = switch (tab) {
                    'leave' => 2,
                    'attendance' => 1,
                    'salary' => 0,
                    _ => 0,
                  };
                  return ShellBranchTicker(
                    branchIndex: 1,
                    child: RecapPage(
                      key: ValueKey('recap-$initialTab-${state.uri}'),
                      initialTabIndex: initialTab,
                    ),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: FaqRouter.faq,
                builder: (context, state) => const ShellBranchTicker(
                  branchIndex: 2,
                  child: FaqPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ProfileRouter.profile,
                builder: (context, state) => const ShellBranchTicker(
                  branchIndex: 3,
                  child: ProfilePage(),
                ),
              ),
            ],
          ),
        ],
      );
}
