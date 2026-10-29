import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/sky_theme.dart';
import '../../../home/theme/home_tokens.dart';
import '../../data/kepuasan_service.dart';

class MoodTrendSection extends StatefulWidget {
  const MoodTrendSection({super.key});

  @override
  State<MoodTrendSection> createState() => _MoodTrendSectionState();
}

class _MoodTrendSectionState extends State<MoodTrendSection> {
  final _service = KepuasanService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _data = [];

  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getMoodTrend(days: _selectedDays);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _service.extractErrorMessage(e);
      });
    }
  }

  String _getEmoji(int score) {
    switch (score) {
      case 1: return '😞';
      case 2: return '😐';
      case 3: return '😊';
      case 4: return '🤩';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: HomeTokens.muted)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }
    if (_data.isEmpty) {
      return const Center(
        child: Text('Belum ada data mood untuk rentang ini.', style: TextStyle(color: HomeTokens.muted)),
      );
    }

    // Menyiapkan data untuk BarChart
    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < _data.length; i++) {
      final score = (_data[i]['score'] as num).toInt();
      final Color barColor = switch (score) {
        1 => const Color(0xFFEF4444), // Sangat Buruk - Merah
        2 => const Color(0xFFF97316), // Buruk - Oranye
        3 => const Color(0xFF22C55E), // Baik - Hijau
        4 => const Color(0xFF0EA5E9), // Sangat Baik - Biru
        _ => HomeTokens.muted,
      };

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: score.toDouble(),
              color: barColor,
              width: _data.length > 14 ? 8 : 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 4.2,
                color: const Color(0xFFF1F5F9),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Riwayat Mood Harian',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: HomeTokens.ink,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: DropdownButton<int>(
                  value: _selectedDays,
                  underline: const SizedBox(),
                  isDense: true,
                  icon: const Icon(Icons.arrow_drop_down, color: HomeTokens.muted, size: 20),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                  onChanged: (val) {
                    if (val != null && val != _selectedDays) {
                      setState(() => _selectedDays = val);
                      _load();
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 Hari')),
                    DropdownMenuItem(value: 14, child: Text('14 Hari')),
                    DropdownMenuItem(value: 30, child: Text('30 Hari')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pantau bagaimana perasaanmu setelah bekerja selama $_selectedDays hari terakhir.',
            style: const TextStyle(
              color: HomeTokens.muted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            height: 280,
            padding: const EdgeInsets.only(top: 32, bottom: 8, left: 12, right: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: HomeTokens.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: 4.2,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    if (value == 0) return const FlLine(color: Colors.transparent);
                    return FlLine(
                      color: HomeTokens.line.withOpacity(0.5),
                      strokeWidth: 1,
                      dashArray: const [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: _data.length > 14 ? (_data.length / 6).ceilToDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 != 0) return const SizedBox.shrink();
                        final index = value.toInt();
                        if (index < 0 || index >= _data.length) return const SizedBox.shrink();
                        
                        final date = _data[index]['date'] as DateTime;
                        final dateStr = DateFormat('d\nMMM').format(date);
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            dateStr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: HomeTokens.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44, // Increased space to avoid overlap with bars
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 != 0) return const SizedBox.shrink();
                        final score = value.toInt();
                        if (score < 1 || score > 4) return const SizedBox.shrink();
                        
                        return Center(
                          child: Text(
                            _getEmoji(score),
                            style: const TextStyle(fontSize: 20), // slightly larger emoji
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => HomeTokens.ink.withOpacity(0.9),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final score = rod.toY.toInt();
                      return BarTooltipItem(
                        _getEmoji(score),
                        const TextStyle(fontSize: 32),
                      );
                    },
                  ),
                ),
              ),
              swapAnimationDuration: const Duration(milliseconds: 600),
              swapAnimationCurve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}
