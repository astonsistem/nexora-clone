import 'package:flutter/material.dart';
import '../../../../core/theme/sky_theme.dart';
import '../../../home/theme/home_tokens.dart';

class MoodTrackerDialog extends StatefulWidget {
  final Function(int score, String emoji) onSubmit;

  const MoodTrackerDialog({super.key, required this.onSubmit});

  static Future<void> show(
    BuildContext context, {
    required Function(int, String) onSubmit,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Mood Tracker',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return MoodTrackerDialog(onSubmit: onSubmit);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: curvedAnimation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  @override
  State<MoodTrackerDialog> createState() => _MoodTrackerDialogState();
}

class _MoodTrackerDialogState extends State<MoodTrackerDialog> {
  final List<Map<String, dynamic>> _moods = [
    {'score': 1, 'emoji': '😞', 'label': 'Buruk'},
    {'score': 2, 'emoji': '😐', 'label': 'Biasa Saja'},
    {'score': 3, 'emoji': '😊', 'label': 'Baik'},
    {'score': 4, 'emoji': '🤩', 'label': 'Luar Biasa'},
  ];

  int? _selectedScore;

  void _submit() {
    if (_selectedScore != null) {
      final selected = _moods.firstWhere((m) => m['score'] == _selectedScore);
      widget.onSubmit(selected['score'], selected['emoji']);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Kerja Keras yang Bagus!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: HomeTokens.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Bagaimana perasaanmu bekerja hari ini?',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: HomeTokens.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: _moods.map((mood) {
                final isSelected = _selectedScore == mood['score'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedScore = mood['score']);
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted) _submit();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? HomeTokens.accentSoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? HomeTokens.accent
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mood['emoji'],
                            style: TextStyle(fontSize: isSelected ? 36 : 28),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            mood['label'],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? HomeTokens.accent
                                  : HomeTokens.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
