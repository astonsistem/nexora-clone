import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_dialog.dart';
import 'app_update_service.dart';

class AppUpdatePrompt {
  static const _dismissedVersionKey = 'app_update_dismissed_version';
  static bool _shownCheckErrorThisSession = false;

  static Future<void> maybeShow(BuildContext context) async {
    final service = AppUpdateService();
    final info = await service.checkForUpdate();
    if (!context.mounted) return;

    if (info == null) {
      if (service.lastCheckFailed && !_shownCheckErrorThisSession) {
        _shownCheckErrorThisSession = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak dapat memeriksa pembaruan aplikasi. Periksa koneksi lalu buka ulang halaman.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (!info.updateAvailable) return;

    final latest = info.latestVersion?.trim() ?? '';
    if (latest.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (!info.forceUpdate) {
      final dismissed = prefs.getString(_dismissedVersionKey);
      if (dismissed == latest) return;
    }

    final url = info.updateUrl?.trim() ?? '';
    if (url.isEmpty) return;

    if (!context.mounted) return;

    final shouldUpdate = await AppUpdateDialog.show(
      context,
      latestVersion: latest,
      releaseNotes: info.releaseNotes,
      forceUpdate: info.forceUpdate,
    );

    if (!context.mounted) return;

    if (shouldUpdate == true) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (!info.forceUpdate) {
      await prefs.setString(_dismissedVersionKey, latest);
    }
  }
}
