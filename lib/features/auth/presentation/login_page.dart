import 'dart:async';
import 'dart:math' as math;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/config/env_config.dart';
import '../../home/router/home_router.dart';
import '../../home/theme/home_tokens.dart';
import '../../profile/presentation/pages/legal_page.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../data/login_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  LoginService get _loginService => ref.read(loginServiceProvider);
  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _linkSubscription;
  late final AnimationController _enter;

  bool _bootstrapping = true;
  bool _isLoading = false;
  bool _openingBrowser = false;
  String? _errorMessage;
  String? _lastExchangedCode;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (EnvConfig.useLocalLogin) {
      if (!mounted) return;
      setState(() => _bootstrapping = false);
      _enter.forward();
      return;
    }

    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      await _handleDeepLink(initialUri);
    } else {
      await _checkExistingSession();
    }

    if (!mounted) return;
    setState(() => _bootstrapping = false);
    _enter.forward();

    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (_) {},
    );
  }

  Future<void> _checkExistingSession() async {
    if (!mounted) return;

    final hasSession = await ref.read(authProvider.future);
    if (hasSession && mounted) {
      await _enterHome();
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (_isLoading) return;

    try {
      final code = _loginService.parseCodeFromUri(uri);
      if (code == null) return;

      if (_lastExchangedCode == code) {
        if (mounted) await _enterHome();
        return;
      }

      setState(() {
        _isLoading = true;
        _openingBrowser = false;
        _errorMessage = null;
        _bootstrapping = false;
      });

      final session = await _loginService.exchangeCode(code);
      _lastExchangedCode = code;

      if (!mounted) return;

      if (session.sessionApproved == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: HomeTokens.ink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: const Text(
              'Login berhasil. Menunggu persetujuan admin untuk perangkat ini.',
            ),
          ),
        );
      }

      await _enterHome();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _openingBrowser = false;
        });
      }
    }
  }

  Future<void> _enterHome() async {
    ref.read(authProvider.notifier).markAuthenticated();
    if (!mounted) return;
    context.go(HomeRouter.home);
    SchedulerBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.scheduleFrame();
    });
  }

  Future<void> _localLogin() async {
    setState(() {
      _isLoading = true;
      _openingBrowser = false;
      _errorMessage = null;
    });
    try {
      await ref.read(authProvider.notifier).signInLocal();
      if (!mounted) return;
      await _enterHome();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startSsoLogin() async {
    setState(() {
      _isLoading = true;
      _openingBrowser = true;
      _errorMessage = null;
    });

    try {
      final oauthUrl = _loginService.buildOAuthUrl();
      final uri = Uri.parse(oauthUrl);
      var launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      if (!launched) {
        throw Exception('Tidak dapat membuka halaman login SSO.');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _openingBrowser = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
        _openingBrowser = false;
      });
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HomeTokens.headerDeep,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: _LoginBackdrop()),
            if (_bootstrapping)
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              )
            else
              SafeArea(
                bottom: false,
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _enter,
                    curve: Curves.easeOutCubic,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: _BrandBlock(enter: _enter),
                      ),
                      _ActionPanel(
                        enter: _enter,
                        isLoading: _isLoading,
                        openingBrowser: _openingBrowser,
                        errorMessage: _errorMessage,
                        bottomInset: bottomInset,
                        onLogin: EnvConfig.useLocalLogin
                            ? _localLogin
                            : _startSsoLogin,
                        onDismissError: () =>
                            setState(() => _errorMessage = null),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              HomeTokens.accent,
              HomeTokens.header,
              HomeTokens.headerDeep,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: _GlowOrb(
                size: 280,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Positioned(
              bottom: 180,
              left: -100,
              child: _GlowOrb(
                size: 220,
                color: HomeTokens.accentSoft.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock({required this.enter});

  final AnimationController enter;

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: enter,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    return SlideTransition(
      position: slide,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BrandLogo(size: 100),
            const SizedBox(height: 22),
            Text(
              EnvConfig.appName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Catat kehadiran dengan aman\nlewat akun perusahaan Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 14.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.enter,
    required this.isLoading,
    required this.openingBrowser,
    required this.errorMessage,
    required this.bottomInset,
    required this.onLogin,
    required this.onDismissError,
  });

  final AnimationController enter;
  final bool isLoading;
  final bool openingBrowser;
  final String? errorMessage;
  final double bottomInset;
  final VoidCallback onLogin;
  final VoidCallback onDismissError;

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: enter,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    final busy = isLoading;
    final label = openingBrowser
        ? 'Membuka OneId…'
        : (isLoading ? 'Memproses login…' : 'Masuk dengan APG OneId');

    return SlideTransition(
      position: slide,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            22,
            22,
            math.max(18, bottomInset + 12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Masuk ke akun Anda',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: HomeTokens.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Anda akan dialihkan ke APG OneId, lalu kembali otomatis.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: HomeTokens.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 14),
                _ErrorBanner(
                  message: errorMessage!,
                  onDismiss: onDismissError,
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: busy ? null : onLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeTokens.accent,
                    disabledBackgroundColor:
                        HomeTokens.accent.withValues(alpha: 0.55),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (busy)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(Icons.shield_rounded, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: HomeTokens.muted.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Login aman melalui APG OneId',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: HomeTokens.muted.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: HomeTokens.line),
              const SizedBox(height: 12),
              const _LoginLegalLinks(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginLegalLinks extends StatelessWidget {
  const _LoginLegalLinks();

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Dengan masuk, Anda menyetujui',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w500,
            color: HomeTokens.muted.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => _open(context, LegalPage.termsOfService()),
              style: TextButton.styleFrom(
                foregroundColor: HomeTokens.accent,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'Terms of Service',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              ' & ',
              style: TextStyle(
                fontSize: 12,
                color: HomeTokens.muted.withValues(alpha: 0.95),
              ),
            ),
            TextButton(
              onPressed: () => _open(context, LegalPage.privacyPolicy()),
              style: TextButton.styleFrom(
                foregroundColor: HomeTokens.accent,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'Privacy Policy',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.close_rounded, size: 18),
            color: const Color(0xFFB91C1C),
          ),
        ],
      ),
    );
  }
}
