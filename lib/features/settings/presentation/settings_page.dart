import 'package:flutter/material.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/sky_theme.dart';
import '../../../shared/widgets/sky_header_background.dart';
import '../../home/theme/home_tokens.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SkyHeaderBand(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 28),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Pengaturan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -18),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                  children: [
                    const Text(
                      'Tampilan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: HomeTokens.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        AppSettings.instance,
                        SkyTheme.instance,
                      ]),
                      builder: (context, _) {
                        final enabled =
                            AppSettings.instance.dynamicSkyEnabled;
                        final accent = SkyTheme.instance.accent;
                        return _SettingCard(
                          icon: Icons.wb_twilight_rounded,
                          iconColor: enabled
                              ? accent
                              : HomeTokens.accent,
                          title: 'Langit dinamis',
                          subtitle: enabled
                              ? 'Header & aksen tombol mengikuti waktu hari.'
                              : 'Header & tombol tetap biru default.',
                          trailing: Switch.adaptive(
                            value: enabled,
                            activeThumbColor: Colors.white,
                            activeTrackColor: accent,
                            onChanged: (v) => AppSettings.instance
                                .setDynamicSkyEnabled(v),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Notifikasi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: HomeTokens.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListenableBuilder(
                      listenable: AppSettings.instance,
                      builder: (context, _) {
                        final enabled =
                            AppSettings.instance.notificationTtsEnabled;
                        final accent = SkyTheme.instance.accent;
                        return _SettingCard(
                          icon: Icons.record_voice_over_rounded,
                          iconColor: enabled
                              ? accent
                              : HomeTokens.accent,
                          title: 'Aktifkan Suara Notifikasi',
                          subtitle: enabled
                              ? 'Dibacakan saat app terbuka/minimized. Matikan batasan baterai Absensi di pengaturan HP agar lebih sering berhasil di luar app.'
                              : 'Matikan jika tidak ingin notifikasi dibacakan.',
                          trailing: Switch.adaptive(
                            value: enabled,
                            activeThumbColor: Colors.white,
                            activeTrackColor: accent,
                            onChanged: (v) => AppSettings.instance
                                .setNotificationTtsEnabled(v),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: HomeTokens.line),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cara kerja',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: HomeTokens.ink,
                            ),
                          ),
                          SizedBox(height: 8),
                          _HintRow(
                            icon: Icons.palette_outlined,
                            text:
                                'Tombol, tab, dan bottom nav ikut warna aksen fase langit',
                          ),
                          _HintRow(
                            icon: Icons.wb_sunny_rounded,
                            text:
                                'Pagi biru cerah · Siang terang · Sore oranye senja · Malam indigo',
                          ),
                          _HintRow(
                            icon: Icons.wb_twilight_rounded,
                            text:
                                'Matahari/bulan bergerak timur → barat mengikuti jam',
                          ),
                          _HintRow(
                            icon: Icons.cloud_rounded,
                            text: 'Awan bergeser pelan tanpa loncatan',
                          ),
                          _HintRow(
                            icon: Icons.record_voice_over_outlined,
                            text:
                                'Suara notifikasi memakai TTS bahasa Indonesia (semua user bisa aktifkan)',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeTokens.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: HomeTokens.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: HomeTokens.muted,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: SkyTheme.instance.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
                color: HomeTokens.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
