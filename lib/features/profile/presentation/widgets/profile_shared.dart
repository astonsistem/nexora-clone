import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/widgets/sky_header_background.dart';
import '../../../home/theme/home_tokens.dart';

String profileDisplay(String? value) {
  if (value == null || value.trim().isEmpty) return '-';
  return value.trim();
}

String profileFormatDate(String? value) {
  if (value == null || value.isEmpty) return '-';
  final s = value.length >= 10 ? value.substring(0, 10) : value;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return s;
  return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
}

String profileGenderLabel(String? value) {
  switch (value?.toLowerCase()) {
    case 'l':
    case 'laki-laki':
    case 'male':
      return 'Laki-laki';
    case 'p':
    case 'perempuan':
    case 'female':
      return 'Perempuan';
    default:
      return profileDisplay(value);
  }
}

String profileMaritalLabel(String? value) {
  switch (value) {
    case 'belum_kawin':
      return 'Belum kawin';
    case 'kawin':
      return 'Kawin';
    case 'cerai_hidup':
      return 'Cerai hidup';
    case 'cerai_mati':
      return 'Cerai mati';
    case 'berpisah':
      return 'Berpisah';
    default:
      return profileDisplay(value);
  }
}

String profilePkwtLabel(String? value) {
  switch (value) {
    case 'pkwtt':
      return 'PKWTT (Tetap)';
    case 'pkwt':
      return 'PKWT (Kontrak)';
    default:
      return profileDisplay(value);
  }
}

String profileEmploymentStatusLabel(String? value) {
  switch (value) {
    case 'prospect':
      return 'Prospect';
    case 'active':
      return 'Aktif';
    case 'inactive':
      return 'Nonaktif';
    default:
      return profileDisplay(value);
  }
}

String profileReligionLabel(String? value) {
  if (value == null || value.trim().isEmpty) return '-';
  final raw = value.trim();
  if (raw.isEmpty) return '-';
  return raw[0].toUpperCase() + raw.substring(1);
}

String profilePkwtReviewLabel(String? value) {
  switch (value) {
    case 'reviewing':
      return 'Dalam review';
    case 'confirmed':
      return 'Dikonfirmasi';
    default:
      return profileDisplay(value);
  }
}

String profileScheduleSourceLabel(String? value) {
  switch (value) {
    case 'override':
      return 'Jadwal individu';
    case 'group':
      return 'Jadwal grup';
    case 'none':
      return 'Tidak ada';
    default:
      return profileDisplay(value);
  }
}

String profileYesNo(bool? value) {
  if (value == null) return '-';
  return value ? 'Ya' : 'Tidak';
}

class ProfileFlatSectionLabel extends StatelessWidget {
  const ProfileFlatSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: HomeTokens.muted,
      ),
    );
  }
}

class ProfileFlatField extends StatelessWidget {
  const ProfileFlatField({
    super.key,
    required this.label,
    required this.value,
    this.copyable = false,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool copyable;
  final bool showDivider;

  Future<void> _copy(BuildContext context) async {
    if (!copyable || value == '-') return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label disalin'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: copyable ? () => _copy(context) : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: HomeTokens.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: HomeTokens.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (copyable && value != '-')
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: HomeTokens.muted.withValues(alpha: 0.65),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, color: HomeTokens.line),
      ],
    );
  }
}

class ProfileDetailScaffold extends StatelessWidget {
  const ProfileDetailScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
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
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: HomeTokens.ink,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: HomeTokens.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? HomeTokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
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
              const Icon(
                Icons.chevron_right_rounded,
                color: HomeTokens.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
