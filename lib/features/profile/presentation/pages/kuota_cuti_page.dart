import 'package:flutter/material.dart';

import '../../../home/data/models/user_profile.dart';
import '../../../home/theme/home_tokens.dart';
import '../widgets/profile_shared.dart';

class KuotaCutiPage extends StatelessWidget {
  const KuotaCutiPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final remaining = profile.leaveRemaining;
    final quota = profile.leaveQuota;
    final used = profile.leaveUsed;
    final remainingLabel = remaining == null
        ? 'Tidak dibatasi'
        : '$remaining hari';
    final remainingColor = remaining == null
        ? HomeTokens.muted
        : (remaining <= 0 ? const Color(0xFFDC2626) : HomeTokens.success);

    final usedLabel = quota == null && remaining == null
        ? '$used hari'
        : '$used / ${quota ?? '∞'} hari';

    final idtUsed = profile.idtIpcUsedThisMonth;
    final idtMax = profile.idtIpcMonthlyMax;
    final idtExhausted = idtUsed >= idtMax;

    return ProfileDetailScaffold(
      title: 'Kuota Cuti / Izin',
      subtitle: 'Sisa cuti dan batas IDT+IPC',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Sisa cuti',
                  value: remainingLabel,
                  valueColor: remainingColor,
                  icon: Icons.beach_access_rounded,
                  iconColor: remainingColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Terpakai',
                  value: usedLabel,
                  valueColor: HomeTokens.ink,
                  icon: Icons.event_available_rounded,
                  iconColor: HomeTokens.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProfileSectionCard(
            title: 'Periode cuti',
            children: [
              ProfileInfoRow(
                label: 'Mulai',
                value: profileFormatDate(profile.leavePeriodStart),
              ),
              ProfileInfoRow(
                label: 'Selesai',
                value: profileFormatDate(profile.leavePeriodEnd),
              ),
              if (quota != null)
                ProfileInfoRow(
                  label: 'Kuota periode',
                  value: '$quota hari',
                ),
            ],
          ),
          const SizedBox(height: 12),
          ProfileSectionCard(
            title: 'IDT + IPC periode berjalan',
            children: [
              if (profile.idtIpcPeriodStart != null &&
                  profile.idtIpcPeriodEnd != null)
                ProfileInfoRow(
                  label: 'Periode',
                  value:
                      '${profileFormatDate(profile.idtIpcPeriodStart)} – ${profileFormatDate(profile.idtIpcPeriodEnd)}',
                ),
              ProfileInfoRow(
                label: 'Batas periode',
                value: '$idtMax× (reset tiap tgl 21)',
              ),
              ProfileInfoRow(
                label: 'Terpakai',
                value: '$idtUsed / $idtMax',
                valueColor:
                    idtExhausted ? const Color(0xFFDC2626) : HomeTokens.ink,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: idtMax <= 0
                        ? 0
                        : (idtUsed / idtMax).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: idtExhausted
                        ? const Color(0xFFDC2626)
                        : HomeTokens.accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: HomeTokens.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
