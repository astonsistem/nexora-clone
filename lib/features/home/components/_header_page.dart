import 'package:flutter/material.dart';

import '../theme/home_tokens.dart';

class HeaderPage extends StatelessWidget {
  const HeaderPage({
    super.key,
    this.name = 'User',
    this.company = '-',
    this.avatarUrl,
    this.notificationCount = 0,
    this.onNotificationTap,
    this.onAvatarTap,
    this.onPrimary = false,
    this.accent,
    this.accentSoft,
  });

  final String name;
  final String company;
  final String? avatarUrl;
  final int notificationCount;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAvatarTap;
  final bool onPrimary;
  final Color? accent;
  final Color? accentSoft;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  String get _initials {
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
    final greetColor = onPrimary
        ? Colors.white.withValues(alpha: 0.78)
        : HomeTokens.muted;
    final nameColor = onPrimary ? Colors.white : HomeTokens.ink;
    final companyColor = onPrimary
        ? Colors.white.withValues(alpha: 0.72)
        : HomeTokens.muted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: greetColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: nameColor,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  company,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: companyColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _NotificationButton(
            count: notificationCount,
            onTap: onNotificationTap,
            onPrimary: onPrimary,
          ),
          const SizedBox(width: 8),
          _ProfileAvatar(
            avatarUrl: avatarUrl,
            initials: _initials,
            onTap: onAvatarTap,
            onPrimary: onPrimary,
            accent: accent ?? HomeTokens.accent,
            accentSoft: accentSoft ?? HomeTokens.accentSoft,
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.initials,
    required this.accent,
    required this.accentSoft,
    this.onTap,
    this.onPrimary = false,
  });

  final String? avatarUrl;
  final String initials;
  final Color accent;
  final Color accentSoft;
  final VoidCallback? onTap;
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onPrimary
              ? Colors.white.withValues(alpha: 0.18)
              : accentSoft,
        ),
        clipBehavior: Clip.antiAlias,
        child: avatarUrl != null
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                width: 44,
                height: 44,
                alignment: Alignment.center,
                errorBuilder: (_, _, _) => _InitialsBadge(
                  initials: initials,
                  accent: accent,
                  accentSoft: accentSoft,
                ),
              )
            : _InitialsBadge(
                initials: initials,
                accent: accent,
                accentSoft: accentSoft,
              ),
      ),
    );
  }
}

class _InitialsBadge extends StatelessWidget {
  const _InitialsBadge({
    required this.initials,
    required this.accent,
    required this.accentSoft,
  });

  final String initials;
  final Color accent;
  final Color accentSoft;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: accentSoft,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({
    required this.count,
    this.onTap,
    this.onPrimary = false,
  });

  final int count;
  final VoidCallback? onTap;
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(
              count > 0
                  ? Icons.notifications_rounded
                  : Icons.notifications_none_rounded,
              size: 26,
              color: onPrimary ? Colors.white : const Color(0xFF475569),
            ),
            if (count > 0)
              Positioned(
                right: count > 9 ? 0 : 4,
                top: 4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: EdgeInsets.symmetric(
                    horizontal: count > 9 ? 4 : 0,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: onPrimary
                          ? const Color(0xFFE85D4C)
                          : Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
