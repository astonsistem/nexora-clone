import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/home_tokens.dart';

class MapsCard extends StatelessWidget {
  const MapsCard({
    super.key,
    this.officeName = 'Kantor',
    this.address = '-',
    this.isWithinRadius = true,
    this.isWfh = false,
    this.latitude,
    this.longitude,
    this.onPrimary = false,
    this.onTap,
  });

  final String officeName;
  final String address;
  final bool isWithinRadius;
  final bool isWfh;
  final double? latitude;
  final double? longitude;
  final bool onPrimary;
  final VoidCallback? onTap;

  Future<void> _openMaps(BuildContext context) async {
    if (onTap != null) {
      onTap!();
      return;
    }

    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Titik lokasi penempatan belum tersedia.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final candidates = <Uri>[
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
      Uri.parse('geo:$lat,$lng?q=$lat,$lng'),
    ];

    for (final uri in candidates) {
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat membuka aplikasi peta.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = isWfh
        ? HomeTokens.wfh
        : (isWithinRadius ? HomeTokens.success : HomeTokens.warning);
    final statusLabel = isWfh
        ? 'WFH'
        : (isWithinRadius ? 'Dalam radius' : 'Luar radius');
    final statusIcon = isWfh
        ? Icons.home_work_rounded
        : (isWithinRadius
            ? Icons.my_location_rounded
            : Icons.location_off_rounded);
    final canOpen = latitude != null && longitude != null;

    final cardColor = onPrimary
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white;
    final titleColor = onPrimary ? Colors.white : HomeTokens.ink;
    final subColor = onPrimary
        ? Colors.white.withValues(alpha: 0.72)
        : HomeTokens.muted;
    final borderColor = onPrimary
        ? Colors.white.withValues(alpha: 0.28)
        : HomeTokens.line;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openMaps(context),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: onPrimary
                        ? Colors.white.withValues(alpha: 0.18)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: onPrimary ? Colors.white : const Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        officeName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        canOpen
                            ? (address.trim().isEmpty || address == '-'
                                ? 'Ketuk untuk buka peta'
                                : address)
                            : address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.25,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: onPrimary
                          ? Colors.white.withValues(alpha: 0.92)
                          : statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 13, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
