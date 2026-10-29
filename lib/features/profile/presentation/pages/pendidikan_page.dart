import 'package:flutter/material.dart';

import '../../../../core/theme/sky_theme.dart';
import '../../../home/data/models/employee_education.dart';
import '../../../home/data/models/user_profile.dart';
import '../../../home/theme/home_tokens.dart';
import '../widgets/profile_shared.dart';

class PendidikanPage extends StatelessWidget {
  const PendidikanPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final items = profile.educations;

    return ProfileDetailScaffold(
      title: 'Riwayat Pendidikan',
      subtitle: 'Timeline sekolah & institusi',
      child: items.isEmpty
          ? const _EmptyEducation()
          : SkyAccentBuilder(
              builder: (context, accent, accentSoft) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                  children: [
                    _EducationSummary(
                      count: items.length,
                      accent: accent,
                      accentSoft: accentSoft,
                    ),
                    const SizedBox(height: 20),
                    ...List.generate(items.length, (index) {
                      final row = items[index];
                      final isLast = index == items.length - 1;
                      final ongoing = row.endedAt == null ||
                          row.endedAt!.trim().isEmpty;
                      return _EducationTimelineItem(
                        index: index,
                        education: row,
                        isLast: isLast,
                        ongoing: ongoing,
                        accent: accent,
                      );
                    }),
                  ],
                );
              },
            ),
    );
  }
}

class _EducationSummary extends StatelessWidget {
  const _EducationSummary({
    required this.count,
    required this.accent,
    required this.accentSoft,
  });

  final int count;
  final Color accent;
  final Color accentSoft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentSoft,
            Color.lerp(accentSoft, Colors.white, 0.55)!,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.school_rounded, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count riwayat tercatat',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Urutan dari data terbaru ke terlama',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: HomeTokens.muted,
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

class _EducationTimelineItem extends StatelessWidget {
  const _EducationTimelineItem({
    required this.index,
    required this.education,
    required this.isLast,
    required this.ongoing,
    required this.accent,
  });

  final int index;
  final EmployeeEducation education;
  final bool isLast;
  final bool ongoing;
  final Color accent;

  static const _palette = <Color>[
    Color(0xFF2563EB),
    Color(0xFF0D9488),
    Color(0xFF0284C7),
    Color(0xFFEA580C),
    Color(0xFF4F46E5),
  ];

  Color get _tone => _palette[index % _palette.length];

  String get _period {
    final start = profileFormatDate(education.startedAt);
    final end = ongoing ? 'Sekarang' : profileFormatDate(education.endedAt);
    return '$start – $end';
  }

  String get _levelHint {
    final name = (education.name ?? '').toLowerCase();
    if (name.contains('s3') || name.contains('doktor')) return 'S3';
    if (name.contains('s2') || name.contains('magister')) return 'S2';
    if (name.contains('s1') || name.contains('sarjana')) return 'S1';
    if (name.contains('d4')) return 'D4';
    if (name.contains('d3') || name.contains('diploma')) return 'D3';
    if (name.contains('d2')) return 'D2';
    if (name.contains('d1')) return 'D1';
    if (name.contains('sma') ||
        name.contains('smk') ||
        name.contains('slta')) {
      return 'SMA/SMK';
    }
    if (name.contains('smp') || name.contains('sltp')) return 'SMP';
    if (name.contains('sd ') || name.startsWith('sd')) return 'SD';
    return 'Edu';
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    final toneSoft = Color.lerp(tone, Colors.white, 0.88)!;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ongoing ? tone : toneSoft,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tone.withValues(alpha: 0.45),
                      width: 2,
                    ),
                    boxShadow: ongoing
                        ? [
                            BoxShadow(
                              color: tone.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: ongoing
                      ? const Icon(
                          Icons.auto_stories_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: tone,
                          ),
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            tone.withValues(alpha: 0.45),
                            HomeTokens.line,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: ongoing
                        ? tone.withValues(alpha: 0.35)
                        : HomeTokens.line,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (ongoing ? tone : Colors.black)
                          .withValues(alpha: ongoing ? 0.10 : 0.04),
                      blurRadius: ongoing ? 14 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: toneSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _levelHint,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: tone,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (ongoing)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: HomeTokens.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 7,
                                  color: HomeTokens.success,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Berlangsung',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: HomeTokens.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      profileDisplay(education.name),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: HomeTokens.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (profileDisplay(education.position) != '-') ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 15,
                            color: tone.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              profileDisplay(education.position),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                                color: HomeTokens.ink.withValues(alpha: 0.78),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 15,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _period,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: HomeTokens.muted,
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
          ),
        ],
      ),
    );
  }
}

class _EmptyEducation extends StatelessWidget {
  const _EmptyEducation();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    HomeTokens.accentSoft,
                    Color.lerp(HomeTokens.accentSoft, Colors.white, 0.5)!,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_outlined,
                color: HomeTokens.accent,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Belum ada riwayat pendidikan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: HomeTokens.ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Data pendidikan belum diisi oleh HR.\nNanti timeline-nya muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: HomeTokens.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
