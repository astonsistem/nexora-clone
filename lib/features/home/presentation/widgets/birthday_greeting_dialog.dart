import 'package:flutter/material.dart';

import '../../theme/home_tokens.dart';
import 'birthday_cake_illustration.dart';

class BirthdayGreetingDialog extends StatefulWidget {
  final String name;

  const BirthdayGreetingDialog({super.key, required this.name});

  static Future<bool?> show(BuildContext context, String name) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Birthday Dialog',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BirthdayGreetingDialog(name: name);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<BirthdayGreetingDialog> createState() => _BirthdayGreetingDialogState();
}

class _BirthdayGreetingDialogState extends State<BirthdayGreetingDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _cakeController;
  late Animation<double> _cakeScale;

  @override
  void initState() {
    super.initState();
    _cakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _cakeScale = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _cakeController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _cakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _firstName(widget.name);
    final theme = Theme.of(context);

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BirthdayModalHero(
                cakeScale: _cakeScale,
                onClose: () => Navigator.of(context).pop(false),
              ),
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Selamat ulang tahun, $firstName!',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: HomeTokens.ink,
                        height: 1.25,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Semoga di usia yang baru penuh kebahagiaan, '
                      'kesehatan, dan hal-hal baik. Terima kasih sudah '
                      'berkontribusi bersama tim.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: HomeTokens.muted,
                        height: 1.55,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: HomeTokens.header,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text(
                          'Terima Kasih!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _firstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Kak';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

class _BirthdayModalHero extends StatelessWidget {
  const _BirthdayModalHero({
    required this.cakeScale,
    required this.onClose,
  });

  final Animation<double> cakeScale;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [HomeTokens.header, HomeTokens.headerDeep],
              ),
            ),
            child: SizedBox.expand(),
          ),
          Positioned(
            top: -28,
            right: -20,
            child: _HeroOrb(size: 96, opacity: 0.12),
          ),
          Positioned(
            bottom: -36,
            left: -24,
            child: _HeroOrb(size: 112, opacity: 0.1),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.white.withValues(alpha: 0.16),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onClose,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: cakeScale,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: BirthdayCakeIllustration(
                        size: 56,
                        style: BirthdayCakeStyle.fabOnPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Happy Birthday',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroOrb extends StatelessWidget {
  const _HeroOrb({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}
