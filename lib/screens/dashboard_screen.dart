import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/driver_score_provider.dart';
import '../widgets/driver_score_gauge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const _greenTop = Color(0xFFE8F5E9);
  static const _greenMid = Color(0xFFF1F8E9);
  static const _greenBottom = Color(0xFFFAFDF7);
  static const _textPrimary = Color(0xFF1B5E20);
  static const _textSecondary = Color(0xFF558B2F);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverScoreProvider>().startListening();
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _insightMessage(String status) {
    switch (status.toUpperCase()) {
      case 'GOOD':
        return 'Emission is at a healthy level.';
      case 'MODERATE':
        return 'Emission is at a moderate level.';
      default:
        return 'Emission is high — drive carefully.';
    }
  }

  List<double> _recentGasBars(DriverScoreProvider provider) {
    final points = provider.history;
    if (points.isEmpty) {
      final base = provider.rawGas <= 0 ? 300.0 : provider.rawGas.clamp(180.0, 750.0);
      return [base * 0.55, base * 0.72, base * 0.88, base];
    }
    final slice =
        points.length >= 4 ? points.sublist(points.length - 4) : points;
    final values = slice.map((p) => p.rawGas).toList();
    while (values.length < 4) {
      values.insert(0, values.first);
    }
    return values;
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
          child: RefreshIndicator(
            color: _textPrimary,
            backgroundColor: Colors.white,
            onRefresh: () async {
              await context.read<DriverScoreProvider>().startListening();
            },
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Consumer2<DriverScoreProvider, AuthProvider>(
                  builder: (context, provider, auth, _) {
                    final name = auth.user?.name.trim().isNotEmpty == true
                        ? auth.user!.name.trim().split(' ').first
                        : 'Driver';
                    final initial =
                        name.isNotEmpty ? name[0].toUpperCase() : 'D';
                    final hasLive = !provider.isLoading ||
                        provider.rawGas > 0 ||
                        provider.humidity > 0 ||
                        provider.temperature > 0;
                    final updated = provider.timestamp;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderRow(
                          plate: provider.licensePlate,
                          initial: initial,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '${_greeting()}, $name',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Smart Vehicle Emission Monitor',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _textSecondary,
                          ),
                        ),
                        if (updated != null) ...[
                          const SizedBox(height: 10),
                          _LiveChip(
                            timeText: DateFormat('HH:mm:ss').format(updated),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFFC8E6C9),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: DriverScoreGauge(
                            score: provider.driverScore,
                            status: provider.status,
                            isLoading: provider.isLoading && !hasLive,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _RawGasCard(
                          value: provider.rawGas,
                          hasLive: hasLive,
                          bars: _recentGasBars(provider),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                title: 'Humidity',
                                valueText: hasLive
                                    ? '${provider.humidity.toStringAsFixed(0)}%'
                                    : '--',
                                progress: hasLive
                                    ? (provider.humidity / 100).clamp(0.0, 1.0)
                                    : 0,
                                icon: Icons.water_drop_rounded,
                                accent: const Color(0xFF039BE5),
                                soft: const Color(0xFFE1F5FE),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                title: 'Temperature',
                                valueText: hasLive
                                    ? '${provider.temperature.toStringAsFixed(1)}°C'
                                    : '--',
                                progress: hasLive
                                    ? ((provider.temperature - 15) / 30)
                                        .clamp(0.0, 1.0)
                                    : 0,
                                icon: Icons.device_thermostat,
                                accent: const Color(0xFFFB8C00),
                                soft: const Color(0xFFFFF3E0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _InsightCard(
                          message: _insightMessage(provider.status),
                        ),
                        if (provider.error != null &&
                            provider.error!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Text(
                              provider.error!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.orange[900],
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.timeText});

  final String timeText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF43A047),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE  ·  $timeText',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2E7D32),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.plate, required this.initial});

  final String plate;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFC8E6C9)),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.directions_car_rounded,
                color: Color(0xFF2E7D32),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                plate,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B5E20),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _RawGasCard extends StatelessWidget {
  const _RawGasCard({
    required this.value,
    required this.hasLive,
    required this.bars,
  });

  final double value;
  final bool hasLive;
  final List<double> bars;

  @override
  Widget build(BuildContext context) {
    final maxBar = bars.fold<double>(1, (a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.air_rounded,
                        color: Color(0xFF2E7D32),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Raw Gas',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF33691E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: hasLive ? value.toStringAsFixed(0) : '--',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1B5E20),
                          height: 1,
                        ),
                      ),
                      TextSpan(
                        text: ' ppm',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF558B2F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(4, (i) {
                final h = ((bars[i] / maxBar) * 36).clamp(8.0, 36.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color.lerp(
                                  const Color(0xFFA5D6A7),
                                  const Color(0xFF2E7D32),
                                  i / 3,
                                )!,
                                Color.lerp(
                                  const Color(0xFFC8E6C9),
                                  const Color(0xFF66BB6A),
                                  i / 3,
                                )!,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${i + 1}m',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            height: 1,
                            color: const Color(0xFF7CB342),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.valueText,
    required this.progress,
    required this.icon,
    required this.accent,
    required this.soft,
  });

  final String title;
  final String valueText;
  final double progress;
  final IconData icon;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
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
            ],
          ),
          const SizedBox(height: 12),
          Text(
            valueText,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B5E20),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: soft,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF1F8E9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFC8E6C9)),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: Color(0xFF43A047),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emission Insight',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF558B2F),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF81C784)),
            ],
          ),
        ),
      ),
    );
  }
}
