import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/shell_page_title.dart';
import '../../../shared/widgets/sky_header_background.dart';
import '../../../shared/navigation/shell_insets.dart';
import '../../../shared/widgets/app_skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../auth/data/login_service.dart';
import '../../auth/router/auth_router.dart';
import '../data/profile_provider.dart';
import '../../home/data/models/user_profile.dart';
import '../../home/theme/home_tokens.dart';
import '../../kepuasan_karyawan/data/kepuasan_fab_refresh.dart';
import '../../pengaduan/presentation/pengaduan_list_page.dart';
import '../../settings/presentation/settings_page.dart';
import 'pages/about_page.dart';
import 'pages/biodata_page.dart';
import 'pages/data_pegawai_page.dart';
import 'pages/kuota_cuti_page.dart';
import 'pages/legal_page.dart';
import 'pages/pendidikan_page.dart';
import 'pages/mood_history_page.dart';
import 'widgets/profile_shared.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _loggingOut = false;
  bool _uploadingPicture = false;

  static const double _sheetOverlap = 22;

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Keluar akun?'),
          content: const Text(
            'Kamu akan keluar dari aplikasi dan perlu login lagi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    await _logout();
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await ref.read(loginServiceProvider).logout();
    } catch (_) {
    } finally {
      await ref.read(authProvider.notifier).signOut();
      if (!mounted) return;
      context.go(AuthRoutes.login);
      setState(() => _loggingOut = false);
    }
  }

  void _openDetail(Widget page) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _changePicture() async {
    if (_uploadingPicture) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingPicture = true);
    try {
      await ref.read(profileProvider.notifier).updatePicture(picked.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil diperbarui')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _uploadingPicture = false);
    }
  }

  String _getInitials(UserProfile? profile) {
    final name = profile?.name ?? '';
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          SkyHeaderBand(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    const ShellPageTitle(title: 'Profil'),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Data akun dan informasi kerja',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (profile != null)
                      _HeaderIdentity(
                        name: profile.name,
                        subtitle: [
                          if (profile.positionName != null &&
                              profile.positionName!.isNotEmpty)
                            profile.positionName!,
                          if (profile.companyName != null &&
                              profile.companyName!.isNotEmpty)
                            profile.companyName!,
                        ].join(' · '),
                        pictureUrl: profile.pictureUrl,
                        initials: _getInitials(profile),
                        uploading: _uploadingPicture,
                        onChangePicture: _changePicture,
                      ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -_sheetOverlap),
              child: Padding(
                padding: const EdgeInsets.only(bottom: _sheetOverlap),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Expanded(child: _buildBody(profileAsync)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue<UserProfile> profileAsync) {
    return profileAsync.when(
      data: (profile) {
        final eduCount = profile.educations.length;
        final leaveHint = profile.leaveRemaining == null
            ? 'Tidak dibatasi'
            : 'Sisa ${profile.leaveRemaining} hari';

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(profileProvider.notifier).refresh();
            KepuasanFabRefresh.instance.ping();
          },
          color: HomeTokens.accent,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              shellBottomContentPadding(context),
            ),
            children: [
          const Text(
            'Informasi saya',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: HomeTokens.muted,
            ),
          ),
          const SizedBox(height: 10),
          ProfileMenuTile(
            icon: Icons.badge_outlined,
            iconColor: HomeTokens.accent,
            title: 'Biodata Pegawai',
            subtitle: 'Identitas, kontak, dan alamat',
            onTap: () => _openDetail(BiodataPage(profile: profile)),
          ),
          const SizedBox(height: 10),
          ProfileMenuTile(
            icon: Icons.work_outline_rounded,
            iconColor: const Color(0xFF0D9488),
            title: 'Data Pegawai',
            subtitle: 'Posisi, cabang, jadwal, dan PKWT',
            onTap: () => _openDetail(DataPegawaiPage(profile: profile)),
          ),
          const SizedBox(height: 10),
          ProfileMenuTile(
            icon: Icons.school_outlined,
            iconColor: const Color(0xFF7C3AED),
            title: 'Riwayat Pendidikan',
            subtitle: eduCount == 0
                ? 'Belum ada data pendidikan'
                : '$eduCount riwayat tercatat',
            onTap: () => _openDetail(PendidikanPage(profile: profile)),
          ),
          const SizedBox(height: 10),
          ProfileMenuTile(
            icon: Icons.event_available_rounded,
            iconColor: HomeTokens.success,
            title: 'Kuota Cuti / Izin',
            subtitle: leaveHint,
            onTap: () => _openDetail(KuotaCutiPage(profile: profile)),
          ),
          const SizedBox(height: 10),
          ProfileMenuTile(
            icon: Icons.mood_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: 'Riwayat Mood',
            subtitle: 'Pantau riwayat mood harianmu',
            onTap: () => _openDetail(const MoodHistoryPage()),
          ),
          const SizedBox(height: 20),
          const Text(
            'Aplikasi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: HomeTokens.muted,
            ),
          ),
          const SizedBox(height: 10),
          _ProfileOutlineButton(
            icon: const Icon(Icons.settings_rounded),
            label: 'Pengaturan',
            onPressed: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              );
            },
          ),
          const SizedBox(height: 10),
          _ProfileOutlineButton(
            icon: const Icon(Icons.forum_outlined),
            label: 'Pengaduan',
            onPressed: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PengaduanListPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _ProfileOutlineButton(
            icon: const Icon(Icons.privacy_tip_outlined),
            label: 'Privacy Policy',
            onPressed: () => _openDetail(LegalPage.privacyPolicy()),
          ),
          const SizedBox(height: 10),
          _ProfileOutlineButton(
            icon: const Icon(Icons.description_outlined),
            label: 'Terms of Service',
            onPressed: () => _openDetail(LegalPage.termsOfService()),
          ),
          const SizedBox(height: 10),
          _ProfileOutlineButton(
            icon: const Icon(Icons.info_outline_rounded),
            label: 'About',
            onPressed: () => _openDetail(const AboutPage()),
          ),
          const SizedBox(height: 10),
          _ProfileOutlineButton(
            icon: _loggingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            label: _loggingOut ? 'Keluar...' : 'Keluar akun',
            onPressed: _loggingOut ? null : _confirmLogout,
            foregroundColor: const Color(0xFFDC2626),
            borderColor: const Color(0xFFFECACA),
          ),
        ],
      ),
    );
      },
      loading: () => const SkeletonProfileBody(),
      error: (err, stack) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  err.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.read(profileProvider.notifier).refresh(),
                  child: const Text('Muat ulang'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileOutlineButton extends StatelessWidget {
  const _ProfileOutlineButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.foregroundColor = HomeTokens.ink,
    this.borderColor = HomeTokens.line,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          side: BorderSide(color: borderColor),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          children: [
            IconTheme(
              data: IconThemeData(color: foregroundColor, size: 22),
              child: icon,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.left,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIdentity extends StatelessWidget {
  const _HeaderIdentity({
    required this.name,
    required this.subtitle,
    required this.initials,
    required this.onChangePicture,
    this.pictureUrl,
    this.uploading = false,
  });

  final String name;
  final String subtitle;
  final String initials;
  final String? pictureUrl;
  final bool uploading;
  final VoidCallback onChangePicture;

  @override
  Widget build(BuildContext context) {
    // Kita menempatkan timestamp buatan agar network image tidak mengambil dari memory cache Flutter lama
    final cacheBustedUrl = pictureUrl == null
        ? null
        : '$pictureUrl${pictureUrl!.contains('?') ? '&' : '?'}v=${DateTime.now().millisecondsSinceEpoch}';

    return Row(
      children: [
        GestureDetector(
          onTap: uploading ? null : onChangePicture,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: cacheBustedUrl != null
                    ? NetworkImage(cacheBustedUrl)
                    : null,
                child: uploading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : (cacheBustedUrl == null
                          ? Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            )
                          : null),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: HomeTokens.accent.withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 14,
                    color: HomeTokens.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                uploading ? 'Mengunggah foto...' : 'Ketuk foto untuk mengganti',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
