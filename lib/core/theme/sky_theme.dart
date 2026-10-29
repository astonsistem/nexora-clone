import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/home/theme/home_tokens.dart';
import '../settings/app_settings.dart';
import '../../shared/widgets/sky_header_background.dart';

class SkyTheme extends ChangeNotifier {
  SkyTheme._();
  static final SkyTheme instance = SkyTheme._();

  Timer? _timer;
  bool _started = false;
  Color _accent = HomeTokens.accent;
  SkyKind _kind = SkyKind.noon;

  Color get accent =>
      AppSettings.instance.dynamicSkyEnabled ? _accent : HomeTokens.accent;

  Color get accentSoft => Color.lerp(accent, Colors.white, 0.82)!;

  SkyKind get kind =>
      AppSettings.instance.dynamicSkyEnabled ? _kind : SkyKind.noon;

  bool get isDynamic => AppSettings.instance.dynamicSkyEnabled;

  void start() {
    if (_started) return;
    _started = true;
    AppSettings.instance.addListener(_sync);
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _sync());
    _sync();
  }

  void disposeController() {
    _timer?.cancel();
    AppSettings.instance.removeListener(_sync);
    _started = false;
  }

  void _sync() {
    final phase = SkyPhase.fromDateTime(DateTime.now());
    final nextAccent = phase.accent;
    final nextKind = phase.kind;
    final enabled = AppSettings.instance.dynamicSkyEnabled;

    if (!enabled) {
      if (_accent != HomeTokens.accent || _kind != SkyKind.noon) {
        _accent = HomeTokens.accent;
        _kind = SkyKind.noon;
        notifyListeners();
      }
      return;
    }

    if (nextAccent != _accent || nextKind != _kind) {
      _accent = nextAccent;
      _kind = nextKind;
      notifyListeners();
    }
  }
}

class SkyAccentBuilder extends StatelessWidget {
  const SkyAccentBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, Color accent, Color accentSoft)
      builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        SkyTheme.instance,
        AppSettings.instance,
      ]),
      builder: (context, _) {
        return builder(
          context,
          SkyTheme.instance.accent,
          SkyTheme.instance.accentSoft,
        );
      },
    );
  }
}
