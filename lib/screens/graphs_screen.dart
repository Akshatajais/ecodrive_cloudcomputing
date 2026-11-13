import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/history_point.dart';
import '../providers/driver_score_provider.dart';

enum TimeFilter { hour, day, week }

class GraphsScreen extends StatefulWidget {
  const GraphsScreen({super.key});

  @override
  State<GraphsScreen> createState() => _GraphsScreenState();
}

class _GraphsScreenState extends State<GraphsScreen> {
  static const _greenTop = Color(0xFFE8F5E9);
  static const _greenMid = Color(0xFFF1F8E9);
  static const _greenBottom = Color(0xFFFAFDF7);
  static const _textPrimary = Color(0xFF1B5E20);
  static const _textSecondary = Color(0xFF558B2F);

  TimeFilter _filter = TimeFilter.day;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverScoreProvider>().fetchHistory();
    });
  }

  Duration get _filterDuration {
    switch (_filter) {
      case TimeFilter.hour:
        return const Duration(hours: 1);
      case TimeFilter.day:
        return const Duration(days: 1);
      case TimeFilter.week:
        return const Duration(days: 7);
    }
  }

  String get _filterLabel {
    switch (_filter) {
      case TimeFilter.hour:
        return 'Last 1 hour';
      case TimeFilter.day:
        return 'Last 24 hours';
      case TimeFilter.week:
        return 'Last 7 days';
    }
  }

  List<HistoryPoint> _filteredHistory(List<HistoryPoint> history) {
    if (history.isEmpty) return history;
    final cutoff = DateTime.now().subtract(_filterDuration);
    final filtered =
        history.where((point) => point.timestamp.isAfter(cutoff)).toList();
    filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return filtered;
  }

  List<FlSpot> _buildSpots(
    List<HistoryPoint> data,
    double Function(HistoryPoint point) mapper,
  ) {
    return List.generate(
      data.length,
      (index) => FlSpot(index.toDouble(), mapper(data[index])),
    );
  }

  double _maxValue(List<FlSpot> spots) {
    if (spots.isEmpty) return 0;
    return spots.map((s) => s.y).reduce(math.max);
  }

  double _avgValue(List<FlSpot> spots) {
    if (spots.isEmpty) return 0;
    final sum = spots.fold<double>(0, (a, b) => a + b.y);
    return sum / spots.length;
  }

  double _dualMax(List<FlSpot> a, List<FlSpot> b) {
    final value = math.max(_maxValue(a), _maxValue(b));
    if (value == 0) return 10;
    return value * 1.15;
  }

  LineChartBarData _line(List<FlSpot> spots, Color color, {double fill = 0.14}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: spots.length <= 12,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeWidth: 1.5,
          strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: fill),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _greenBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_greenTop, _greenMid, _greenBottom],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Consumer<DriverScoreProvider>(
            builder: (context, provider, _) {
              final filtered = _filteredHistory(provider.history);
              final emissionSpots =
                  _buildSpots(filtered, (p) => p.emissionScore);
              final rawGasSpots = _buildSpots(filtered, (p) => p.rawGas);
              final tempSpots = _buildSpots(filtered, (p) => p.temperature);

              return RefreshIndicator(
                color: _textPrimary,
                backgroundColor: Colors.white,
                onRefresh: () => provider.fetchHistory(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Graphs',
                                    style: GoogleFonts.poppins(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Emission trends over time',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => provider.fetchHistory(),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFC8E6C9),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.refresh_rounded,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _FilterRow(
                            selected: _filter,
                            onChanged: (f) => setState(() => _filter = f),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryTile(
                                  label: 'Points',
                                  value: '${filtered.length}',
                                  icon: Icons.timeline_rounded,
                                  accent: const Color(0xFF2E7D32),
                                  soft: const Color(0xFFE8F5E9),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _SummaryTile(
                                  label: 'Avg score',
                                  value: emissionSpots.isEmpty
                                      ? '--'
                                      : _avgValue(emissionSpots)
                                          .toStringAsFixed(0),
                                  icon: Icons.speed_rounded,
                                  accent: const Color(0xFF43A047),
                                  soft: const Color(0xFFE8F5E9),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _SummaryTile(
                                  label: 'Peak gas',
                                  value: rawGasSpots.isEmpty
                                      ? '--'
                                      : _maxValue(rawGasSpots)
                                          .toStringAsFixed(0),
                                  icon: Icons.air_rounded,
                                  accent: const Color(0xFF039BE5),
                                  soft: const Color(0xFFE1F5FE),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _ChartCard(
                            title: 'Emission Score',
                            subtitle: _filterLabel,
                            legends: const [
                              _Legend(color: Color(0xFF43A047), label: 'Score'),
                            ],
                            child: _EmissionChart(
                              data: filtered,
                              spots: emissionSpots,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _ChartCard(
                            title: 'Raw Gas & Temperature',
                            subtitle: 'ppm and °C over $_filterLabel',
                            legends: const [
                              _Legend(
                                color: Color(0xFF2E7D32),
                                label: 'Raw Gas',
                              ),
                              _Legend(
                                color: Color(0xFFFB8C00),
                                label: 'Temp',
                              ),
                            ],
                            child: _DualChart(
                              data: filtered,
                              rawGasSpots: rawGasSpots,
                              temperatureSpots: tempSpots,
                              dualMax: _dualMax(rawGasSpots, tempSpots),
                              buildLine: _line,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onChanged});

  final TimeFilter selected;
  final ValueChanged<TimeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (TimeFilter.hour, '1 hr'),
      (TimeFilter.day, '24 hrs'),
      (TimeFilter.week, '7 days'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8E6C9)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: items.map((item) {
          final isSelected = selected == item.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2E7D32)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  item.$2,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF558B2F),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.soft,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B5E20),
              height: 1.1,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.legends,
    required this.child,
  });

  final String title;
  final String subtitle;
  final List<_Legend> legends;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8F5E9)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.09),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF558B2F),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: legends
                .map(
                  (l) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: l.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: l.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l.label,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: l.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(height: 220, child: child),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.show_chart_rounded,
              color: Color(0xFF66BB6A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No data in this range',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF558B2F),
            ),
          ),
        ],
      ),
    );
  }
}

FlTitlesData _titles(List<HistoryPoint> data, {String unit = ''}) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 36,
        getTitlesWidget: (value, meta) => Text(
          '${value.toInt()}$unit',
          style: GoogleFonts.poppins(
            color: Colors.grey[500],
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 30,
        interval: data.length <= 1 ? 1 : (data.length / 4).ceilToDouble(),
        getTitlesWidget: (value, meta) {
          final index = value.round();
          if (index < 0 || index >= data.length) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              DateFormat('HH:mm').format(data[index].timestamp),
              style: GoogleFonts.poppins(
                color: Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _EmissionChart extends StatelessWidget {
  const _EmissionChart({required this.data, required this.spots});

  final List<HistoryPoint> data;
  final List<FlSpot> spots;

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) return const _EmptyChart();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (spots.length - 1).toDouble().clamp(0, double.infinity),
        minY: 0,
        maxY: 500,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 125,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFFE8F5E9),
            strokeWidth: 1,
          ),
        ),
        titlesData: _titles(data),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1B5E20),
            getTooltipItems: (touched) => touched
                .map(
                  (t) => LineTooltipItem(
                    t.y.toStringAsFixed(0),
                    GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF43A047),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: spots.length <= 12,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: const Color(0xFF43A047),
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF43A047).withValues(alpha: 0.28),
                  const Color(0xFF43A047).withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DualChart extends StatelessWidget {
  const _DualChart({
    required this.data,
    required this.rawGasSpots,
    required this.temperatureSpots,
    required this.dualMax,
    required this.buildLine,
  });

  final List<HistoryPoint> data;
  final List<FlSpot> rawGasSpots;
  final List<FlSpot> temperatureSpots;
  final double dualMax;
  final LineChartBarData Function(List<FlSpot>, Color, {double fill}) buildLine;

  @override
  Widget build(BuildContext context) {
    if (rawGasSpots.isEmpty) return const _EmptyChart();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (rawGasSpots.length - 1).toDouble().clamp(0, double.infinity),
        minY: 0,
        maxY: dualMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFFE8F5E9),
            strokeWidth: 1,
          ),
        ),
        titlesData: _titles(data),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1B5E20),
            getTooltipItems: (touched) => touched
                .map(
                  (t) => LineTooltipItem(
                    t.y.toStringAsFixed(1),
                    GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          buildLine(rawGasSpots, const Color(0xFF2E7D32)),
          buildLine(temperatureSpots, const Color(0xFFFB8C00), fill: 0.08),
        ],
      ),
    );
  }
}
