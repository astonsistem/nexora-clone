import 'package:flutter/material.dart';

import '../../features/home/theme/home_tokens.dart';

class AppUpdateDialog extends StatelessWidget {
  const AppUpdateDialog({
    super.key,
    required this.latestVersion,
    required this.releaseNotes,
    required this.forceUpdate,
  });

  final String latestVersion;
  final String? releaseNotes;
  final bool forceUpdate;

  static Future<bool?> show(
    BuildContext context, {
    required String latestVersion,
    String? releaseNotes,
    required bool forceUpdate,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => AppUpdateDialog(
        latestVersion: latestVersion,
        releaseNotes: releaseNotes,
        forceUpdate: forceUpdate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = releaseNotes?.trim() ?? '';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: HomeTokens.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.system_update_alt_rounded, color: HomeTokens.accent),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Update tersedia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Versi terbaru: v$latestVersion',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: HomeTokens.ink,
              ),
            ),
            const SizedBox(height: 8),
            if (notes.isNotEmpty)
              Text(
                notes,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: HomeTokens.muted,
                ),
              )
            else
              const Text(
                'Perbarui aplikasi untuk mendapatkan perbaikan dan fitur terbaru.',
                style: TextStyle(fontSize: 13, height: 1.45, color: HomeTokens.muted),
              ),
            if (forceUpdate) ...[
              const SizedBox(height: 12),
              Text(
                'Update wajib untuk melanjutkan.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!forceUpdate)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Nanti'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: HomeTokens.accent,
            foregroundColor: Colors.white,
          ),
          child: const Text('Update'),
        ),
      ],
    );
  }
}
