import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/history_point.dart';
import '../providers/driver_score_provider.dart';
import '../services/ml_insights_service.dart';

class MlInsightsScreen extends StatefulWidget {
  const MlInsightsScreen({super.key});

  @override
  State<MlInsightsScreen> createState() => _MlInsightsScreenState();
}

class _MlInsightsScreenState extends State<MlInsightsScreen> {
  static const _greenTop = Color(0xFFE8F5E9);
  static const _greenMid = Color(0xFFF1F8E9);
  static const _greenBottom = Color(0xFFFAFDF7);
  static const _textPrimary = Color(0xFF1B5E20);
  static const _textSecondary = Color(0xFF558B2F);

  final MlInsightsService _ml = MlInsightsService();
  Future<void>? _initFuture;

  MlPrediction? _driver;
  MlPrediction? _vehicle;
  String? _error;
  bool _running = false;

  Timer? _debounce;
  int _lastScheduledHistoryLen = -1;

  @override
  void initState() {
    super.initState();
    _initFuture = _ml.init();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await context.read<DriverScoreProvider>().fetchHistory();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ml.dispose();
    super.dispose();
  }

  void _scheduleRun(List<HistoryPoint> history) {
    if (history.length == _lastScheduledHistoryLen) return;
    _lastScheduledHistoryLen = history.length;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _run(history);
    });
  }

  Future<void> _run(List<HistoryPoint> history) async {
    if (_running) return;
    if (history.length < 20) {
      setState(() {
        _driver = null;
        _vehicle = null;
        _error = null;
      });
      return;
    }

    setState(() {
      _running = true;
      _error = null;
    });

    try {
      await _initFuture;
      final driver = await _ml.predictDriverBehavior(history);
      final vehicle = await _ml.predictVehicleHealth(history);
      if (!mounted) return;
      setState(() {
        _driver = driver;
        _vehicle = vehicle;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'GOOD':
        return const Color(0xFF43A047);
      case 'MODERATE':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFFE53935);
    }
  }

  List<_Recommendation> _recommendations({
    required MlPrediction? driver,
    required MlPrediction? vehicle,
    required double score,
  }) {
    final items = <_Recommendation>[];

    if (driver != null) {
      final label = driver.label.toLowerCase();
      if (label.contains('aggressive')) {
        items.add(
          const _Recommendation(
            icon: Icons.speed_rounded,
            title: 'Smooth acceleration',
            body:
                'Gradual throttle inputs can reduce spikes and improve efficiency.',
          ),
        );
      } else if (label.contains('idle')) {
        items.add(
          const _Recommendation(
            icon: Icons.timer_outlined,
            title: 'Reduce idling',
            body:
                'Turn off the engine during long stops to reduce emissions.',
          ),
        );
      } else if (label.contains('eco')) {
        items.add(
          const _Recommendation(
            icon: Icons.eco_rounded,
            title: 'Keep it up',
            body:
                'Your driving pattern looks efficient — maintain steady speed where possible.',
          ),
        );
      }
    }

    if (vehicle != null) {
      final label = vehicle.label.toLowerCase();
      if (label.contains('critical')) {
        items.add(
          const _Recommendation(
            icon: Icons.build_circle_outlined,
            title: 'Service recommended',
            body:
                'Model indicates possible vehicle health issues — consider a maintenance check.',
          ),
        );
      } else if (label.contains('needs')) {
        items.add(
          const _Recommendation(
            icon: Icons.build_outlined,
            title: 'Preventive maintenance',
            body:
                'Check air filter, spark plugs, and fuel system for improved combustion.',
          ),
        );
      }
    }

    if (items.isEmpty) {
      items.add(
        _Recommendation(
          icon: Icons.insights_rounded,
          title: score > 400 ? 'High emissions detected' : 'Collect more data',
          body: score > 400
              ? 'Consider checking the vehicle and reviewing driving patterns to reduce emissions.'
              : 'Insights refine as more readings arrive (aim for 20+).',
        ),
      );
    }

    return items;
  }

  static String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 10) return 'just now';
    if (d.inMinutes < 1) return '${d.inSeconds}s ago';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
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
              final history = provider.history;
              _scheduleRun(history);
              final needed = (20 - history.length).clamp(0, 20);
              final progress = (history.length / 20).clamp(0.0, 1.0);
              final tips = _recommendations(
                driver: _driver,
                vehicle: _vehicle,
                score: provider.driverScore,
              );

              return RefreshIndicator(
                color: _textPrimary,
                backgroundColor: Colors.white,
                onRefresh: () async {
                  await provider.fetchHistory();
                  await _run(provider.history);
                },
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
                                    'Insights',
                                    style: GoogleFonts.poppins(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'On-device ML from live readings',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_running)
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF2E7D32),
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
                          _LiveSummaryCard(
                            status: provider.status,
                            statusColor: _statusColor(provider.status),
                            lastSource: provider.lastRealtimeSource,
                            score: provider.driverScore,
                            rawGas: provider.rawGas,
                            temperature: provider.temperature,
                            humidity: provider.humidity,
                            timeAgo: provider.lastRealtimeArrival == null
                                ? null
                                : _timeAgo(provider.lastRealtimeArrival!),
                          ),
                          const SizedBox(height: 12),
                          _DataProgressCard(
                            historyLen: history.length,
                            needed: needed,
                            progress: progress,
                          ),
                          const SizedBox(height: 18),
                          _SectionHeader(
                            icon: Icons.psychology_rounded,
                            title: 'ML Predictions',
                            subtitle: 'Based on the last ~80 readings',
                          ),
                          const SizedBox(height: 10),
                          if (_error != null) ...[
                            _ErrorCard(message: _error!),
                            const SizedBox(height: 10),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _PredictionCard(
                                  title: 'Driver behavior',
                                  icon: Icons.directions_car_rounded,
                                  accent: const Color(0xFF43A047),
                                  soft: const Color(0xFFE8F5E9),
                                  prediction: _driver,
                                  isRunning: _running,
                                  emptyHint: history.length < 20
                                      ? 'Need $needed more readings'
                                      : 'Analyzing…',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PredictionCard(
                                  title: 'Vehicle health',
                                  icon: Icons.health_and_safety_rounded,
                                  accent: const Color(0xFF039BE5),
                                  soft: const Color(0xFFE1F5FE),
                                  prediction: _vehicle,
                                  isRunning: _running,
                                  emptyHint: history.length < 20
                                      ? 'Need $needed more readings'
                                      : 'Analyzing…',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _SectionHeader(
                            icon: Icons.lightbulb_outline_rounded,
                            title: 'Suggested actions',
                            subtitle: 'Personalized from live + ML signals',
                          ),
                          const SizedBox(height: 10),
                          ...tips.map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _TipCard(recommendation: r),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF2E7D32), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF558B2F),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveSummaryCard extends StatelessWidget {
  const _LiveSummaryCard({
    required this.status,
    required this.statusColor,
    required this.lastSource,
    required this.score,
    required this.rawGas,
    required this.temperature,
    required this.humidity,
    required this.timeAgo,
  });

  final String status;
  final Color statusColor;
  final String lastSource;
  final double score;
  final double rawGas;
  final double temperature;
  final double humidity;
  final String? timeAgo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFC8E6C9)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live summary',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1B5E20),
                      ),
                    ),
                    Text(
                      'Source: $lastSource'
                      '${timeAgo == null ? '' : '  ·  $timeAgo'}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF558B2F),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Emission',
                  value: score.toStringAsFixed(0),
                  accent: const Color(0xFF43A047),
                  soft: const Color(0xFFE8F5E9),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Raw Gas',
                  value: rawGas.toStringAsFixed(0),
                  unit: 'ppm',
                  accent: const Color(0xFF2E7D32),
                  soft: const Color(0xFFE8F5E9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Temp',
                  value: temperature.toStringAsFixed(1),
                  unit: '°C',
                  accent: const Color(0xFFFB8C00),
                  soft: const Color(0xFFFFF3E0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Humidity',
                  value: humidity.toStringAsFixed(0),
                  unit: '%',
                  accent: const Color(0xFF039BE5),
                  soft: const Color(0xFFE1F5FE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.soft,
    this.unit = '',
  });

  final String label;
  final String value;
  final String unit;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: accent.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B5E20),
                    height: 1.1,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: accent,
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

class _DataProgressCard extends StatelessWidget {
  const _DataProgressCard({
    required this.historyLen,
    required this.needed,
    required this.progress,
  });

  final int historyLen;
  final int needed;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final ready = historyLen >= 20;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                color: ready
                    ? const Color(0xFF43A047)
                    : const Color(0xFFFF9800),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ready
                      ? 'Ready for ML analysis ($historyLen readings)'
                      : 'Collecting data · $needed more needed',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF558B2F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8F5E9),
              valueColor: AlwaysStoppedAnimation<Color>(
                ready ? const Color(0xFF43A047) : const Color(0xFFFF9800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFFC62828),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.soft,
    required this.prediction,
    required this.isRunning,
    required this.emptyHint,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Color soft;
  final MlPrediction? prediction;
  final bool isRunning;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final p = prediction;
    final label = p?.label;
    final conf = p?.confidence ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: soft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              if (isRunning)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (label == null)
            Text(
              emptyHint,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF558B2F),
                height: 1.35,
              ),
            )
          else ...[
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1B5E20),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: conf.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: soft,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Confidence ${(conf * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.recommendation});

  final _Recommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8F5E9)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              recommendation.icon,
              color: const Color(0xFF2E7D32),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  recommendation.body,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF558B2F),
                    height: 1.45,
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

class _Recommendation {
  const _Recommendation({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
