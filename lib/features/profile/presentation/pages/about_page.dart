import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/config/env_config.dart';
import '../../../home/theme/home_tokens.dart';
import '../widgets/profile_shared.dart';

String _platformLabel() {
  if (kIsWeb) return 'Web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
}

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage>
    with SingleTickerProviderStateMixin {

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  String _appVersion = '2.0.5';
  String _buildNumber = '';
  final String _platform = _platformLabel();

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() {
        _appVersion = info.version;
        _buildNumber = info.buildNumber;
      });
    });
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appName = EnvConfig.appName;

    return ProfileDetailScaffold(
      title: 'About',
      subtitle: 'Informasi aplikasi',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
        children: [
          _HeroCard(
            appName: appName,
            pulseAnim: _pulseAnim,
            versionLabel: _buildNumber.isNotEmpty
                ? 'v$_appVersion ($_buildNumber)'
                : 'v$_appVersion',
          ),

          const SizedBox(height: 16),

          _SectionCard(
            icon: Icons.info_outline_rounded,
            iconBg: HomeTokens.accent,
            title: 'Tentang Aplikasi',
            child: Text(
              '$appName adalah aplikasi absensi mobile untuk karyawan. '
              'Gunakan untuk presensi masuk/pulang, pengajuan izin/cuti, '
              'dan melihat rekap kehadiran sesuai kebijakan perusahaan.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.55,
                color: HomeTokens.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 12),

          _SectionCard(
            icon: Icons.auto_awesome_rounded,
            iconBg: HomeTokens.warning,
            title: 'Fitur Utama',
            child: Column(
              children: const [
                _FeatureRow(
                  icon: Icons.fingerprint_rounded,
                  color: HomeTokens.accent,
                  label: 'Absensi GPS',
                  desc: 'Clock-in/out dengan verifikasi lokasi',
                ),
                _FeatureRow(
                  icon: Icons.event_note_rounded,
                  color: HomeTokens.success,
                  label: 'Pengajuan Cuti',
                  desc: 'Ajukan izin & cuti langsung',
                ),
                _FeatureRow(
                  icon: Icons.bar_chart_rounded,
                  color: HomeTokens.wfh,
                  label: 'Rekap Kehadiran',
                  desc: 'Lihat riwayat & statistik absensi',
                ),
                _FeatureRow(
                  icon: Icons.notifications_active_rounded,
                  color: HomeTokens.accent,
                  label: 'Notifikasi',
                  desc: 'Push notification real-time',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _SectionCard(
            icon: Icons.devices_rounded,
            iconBg: HomeTokens.success,
            title: 'Detail',
            child: Column(
              children: [
                _InfoRow(
                  label: 'Versi',
                  value: _buildNumber.isNotEmpty
                      ? '$_appVersion (build $_buildNumber)'
                      : _appVersion,
                ),
                _InfoRow(label: 'Platform', value: _platform),
                const _InfoRow(label: 'Kategori', value: 'Nexora Absensi', isLast: true),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const _FooterBranding(),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.appName,
    required this.pulseAnim,
    required this.versionLabel,
  });

  final String appName;
  final Animation<double> pulseAnim;
  final String versionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HomeTokens.header, HomeTokens.headerDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: HomeTokens.header.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: pulseAnim,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: pulseAnim.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  appName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 6),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    versionLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 0.5,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconBg, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: HomeTokens.ink,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: HomeTokens.line),
          ),
          child,
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.desc,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: HomeTokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: HomeTokens.muted,
                    fontWeight: FontWeight.w500,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: HomeTokens.muted,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: HomeTokens.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: HomeTokens.line),
      ],
    );
  }
}

class _FooterBranding extends StatelessWidget {
  const _FooterBranding();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: HomeTokens.line,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '© ${DateTime.now().year} ${EnvConfig.appName}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: HomeTokens.muted.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}
