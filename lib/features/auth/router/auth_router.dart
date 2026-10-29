import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/config/env_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/router/home_router.dart';
import '../presentation/login_page.dart';
import '../presentation/splash_page.dart';

class AuthRoutes {
  static const splash = '/splash';
  static const login = '/auth/login';

  static List<RouteBase> routes = [
    GoRoute(
      path: splash,
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: login,
      builder: (context, state) => const LoginPage(),
    ),
  ];

  static Future<String?> redirect(
    BuildContext context,
    GoRouterState state,
    Ref ref,
  ) async {
    final loc = state.matchedLocation;
    // Splash mengatur navigasi sendiri setelah animasi singkat.
    if (loc == splash) return null;

    final authState = ref.read(authProvider);
    final isLoggedIn = authState.valueOrNull == true;
    final isLoginRoute = loc == login;

    if (!EnvConfig.useLocalLogin && isLoggedIn && isLoginRoute) {
      return HomeRouter.home;
    }

    if (!isLoggedIn && !isLoginRoute) {
      return login;
    }

    return null;
  }
}
