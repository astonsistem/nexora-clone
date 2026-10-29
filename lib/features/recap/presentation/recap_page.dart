import 'package:flutter/material.dart';

import '../../../core/theme/sky_theme.dart';
import '../../../shared/widgets/shell_page_title.dart';
import '../../../shared/widgets/sky_header_background.dart';
import '../../home/theme/home_tokens.dart';
import 'tabs/attendance_recap_tab.dart';
import 'tabs/leave_recap_tab.dart';
import 'tabs/salary_recap_tab.dart';

class RecapPage extends StatelessWidget {
  const RecapPage({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  static const double _sheetOverlap = 22;

  @override
  Widget build(BuildContext context) {
    final index = initialTabIndex.clamp(0, 2);

    return DefaultTabController(
      key: ValueKey('recap-tab-$index'),
      length: 3,
      initialIndex: index,
      child: Scaffold(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShellPageTitle(title: 'Rekap'),
                      const SizedBox(height: 4),
                      Text(
                        'Gaji, absensi, dan izin dalam satu tempat',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
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
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SkyAccentBuilder(
                            builder: (context, accent, _) {
                              return Container(
                                height: 44,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: TabBar(
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  dividerColor: Colors.transparent,
                                  labelColor: Colors.white,
                                  unselectedLabelColor: HomeTokens.muted,
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                  unselectedLabelStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  indicator: BoxDecoration(
                                    color: accent,
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(11),
                                    ),
                                  ),
                                  tabs: const [
                                    Tab(text: 'Gaji'),
                                    Tab(text: 'Absensi'),
                                    Tab(text: 'Izin & Cuti'),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Expanded(
                          child: TabBarView(
                            children: [
                              SalaryRecapTab(),
                              AttendanceRecapTab(),
                              LeaveRecapTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
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
