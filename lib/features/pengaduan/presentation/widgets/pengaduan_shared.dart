import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/sky_theme.dart';
import '../../../../shared/widgets/sky_header_background.dart';
import '../../../home/theme/home_tokens.dart';

String ticketStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'IN_PROGRESS':
      return 'Diproses';
    case 'RESOLVED':
      return 'Selesai';
    case 'REJECTED':
      return 'Ditolak';
    case 'PENDING':
    default:
      return 'Menunggu';
  }
}

Color ticketStatusColor(String status) {
  switch (status.toUpperCase()) {
    case 'IN_PROGRESS':
      return SkyTheme.instance.accent;
    case 'RESOLVED':
      return HomeTokens.success;
    case 'REJECTED':
      return const Color(0xFFDC2626);
    case 'PENDING':
    default:
      return HomeTokens.warning;
  }
}

String ticketDate(DateTime? value, {bool withTime = false}) {
  if (value == null) return '-';
  return DateFormat(
    withTime ? 'd MMM yyyy, HH:mm' : 'd MMM yyyy',
    'id',
  ).format(value.toLocal());
}

class TicketStatusBadge extends StatelessWidget {
  const TicketStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return SkyAccentBuilder(
      builder: (context, _, _) {
        final color = ticketStatusColor(status);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.24)),
          ),
          child: Text(
            ticketStatusLabel(status),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      },
    );
  }
}

class PengaduanScaffold extends StatelessWidget {
  const PengaduanScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  static const double sheetOverlap = 22;

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: Column(
        children: [
          SkyHeaderBand(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        ...?actions,
                      ],
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -sheetOverlap),
              child: Padding(
                padding: const EdgeInsets.only(bottom: sheetOverlap),
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
                      const SizedBox(height: 8),
                      Expanded(child: body),
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
}

InputDecoration pengaduanInputDecoration({
  required String label,
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final accent = SkyTheme.instance.accent;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    alignLabelWithHint: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: HomeTokens.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: HomeTokens.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: accent, width: 1.5),
    ),
  );
}
