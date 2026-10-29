import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_provider.dart';
import '../core/config/env_config.dart';
import '../core/settings/app_settings.dart';
import '../core/theme/sky_theme.dart';
import 'router.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SchedulerBinding.instance.scheduleFrame();
      if (mounted) setState(() {});
      unawaited(ref.read(authProvider.notifier).onAppResumed());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: EnvConfig.appName,
          debugShowCheckedModeBanner: false,
          locale: const Locale('id'),
          supportedLocales: const [
            Locale('id'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: HomeAccent.seed),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: HomeAccent.seed,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          builder: (context, child) {
            return ListenableBuilder(
              listenable: Listenable.merge([
                SkyTheme.instance,
                AppSettings.instance,
              ]),
              builder: (context, _) {
                final accent = SkyTheme.instance.accent;
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.fromSeed(seedColor: accent),
                    filledButtonTheme: FilledButtonThemeData(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
            );
          },
          routerConfig: ref.watch(routerProvider),
        );
      },
    );
  }
}

class HomeAccent {
  static const seed = Color(0xFF7C3AED);
}
