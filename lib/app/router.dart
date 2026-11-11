import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/router/auth_router.dart';
import '../features/recap/presentation/salary_detail_page.dart';
import 'app_navigator.dart';
import 'shell_router.dart';
import '../core/auth/auth_provider.dart';

class AppRouter {
  static final rootNavigatorKey = AppNavigator.rootKey;
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ValueNotifier<int>(0);

  ref.listen(authProvider, (_, _) {
    listenable.value++;
  });

  return GoRouter(
    navigatorKey: AppNavigator.rootKey,
    initialLocation: AuthRoutes.splash,
    refreshListenable: listenable,
    redirect: (context, state) => AuthRoutes.redirect(context, state, ref),
    onException: (context, state, router) {
      final login = AuthRoutes.redirectFromOAuthDeepLink(state);
      router.go(login ?? AuthRoutes.login);
    },
    routes: [
      ...AuthRoutes.routes,
      ShellRouter.shellRoute,
      GoRoute(
        path: '/recap/gaji/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return SalaryDetailPage(id: id);
        },
      ),
    ],
  );
});
