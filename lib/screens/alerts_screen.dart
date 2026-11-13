import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/emission_alert.dart';
import '../providers/driver_score_provider.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  static const _greenTop = Color(0xFFE8F5E9);
  static const _greenMid = Color(0xFFF1F8E9);
  static const _greenBottom = Color(0xFFFAFDF7);
  static const _textPrimary = Color(0xFF1B5E20);
  static const _textSecondary = Color(0xFF558B2F);

  List<({IconData icon, String text})> _getHealthTips(double score) {
    if (score <= 150) {
      return [
        (icon: Icons.check_circle_outline, text: 'Excellent emission levels'),
        (
          icon: Icons.thumb_up_alt_outlined,
          text: 'Vehicle is running efficiently'
        ),
        (
          icon: Icons.build_circle_outlined,
          text: 'Keep your maintenance schedule active'
        ),
        (icon: Icons.eco_outlined, text: 'Continue eco-friendly driving habits'),
      ];
    }
    if (score <= 300) {
      return [
        (icon: Icons.info_outline, text: 'Moderate emission levels'),
        (
          icon: Icons.build_outlined,
          text: 'Regular maintenance recommended'
        ),
        (
          icon: Icons.filter_alt_outlined,
          text: 'Inspect air and fuel filters'
        ),
        (
          icon: Icons.speed_outlined,
          text: 'Practice smooth acceleration'
        ),
      ];
    }
    return [
      (
        icon: Icons.warning_amber_rounded,
        text: 'High emission detected — action recommended'
      ),
      (
        icon: Icons.car_repair_outlined,
        text: 'Check engine for potential issues'
      ),
      (
        icon: Icons.air_outlined,
        text: 'Clean or replace the air filter'
      ),
      (
        icon: Icons.event_available_outlined,
        text: 'Schedule vehicle maintenance soon'
      ),
    ];
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

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'GOOD':
        return Icons.check_circle_rounded;
      case 'MODERATE':
        return Icons.warning_amber_rounded;
      default:
        return Icons.error_rounded;
    }
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
              final score = provider.driverScore;
              final alerts = provider.alertLogs;
              final statusColor = _statusColor(provider.status);
              final tips = _getHealthTips(score);

              return RefreshIndicator(
                color: _textPrimary,
                backgroundColor: Colors.white,
                onRefresh: () async {
                  await provider.startListening();
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
                                    'Alerts',
                                    style: GoogleFonts.poppins(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Live warnings & health tips',
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
                              elevation: 0,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => provider.startListening(),
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
                          _StatusHero(
                            score: score,
                            status: provider.status,
                            color: statusColor,
                            icon: _statusIcon(provider.status),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  label: 'Warnings',
                                  value: '${alerts.length}',
                                  icon: alerts.isEmpty
                                      ? Icons.check_circle_rounded
                                      : Icons.notifications_active_rounded,
                                  accent: alerts.isEmpty
                                      ? const Color(0xFF43A047)
                                      : const Color(0xFFE53935),
                                  soft: alerts.isEmpty
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFFFEBEE),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatTile(
                                  label: 'Status',
                                  value: provider.status,
                                  icon: _statusIcon(provider.status),
                                  accent: statusColor,
                                  soft: statusColor.withValues(alpha: 0.12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _SectionTitle(title: 'Health Recommendations'),
                          const SizedBox(height: 10),
                          ...tips.map(
                            (tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _TipCard(
                                icon: tip.icon,
                                text: tip.text,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _SectionTitle(title: 'Current Sensors'),
                          const SizedBox(height: 10),
                          _SensorsCard(
                            rawGas: provider.rawGas,
                            temperature: provider.temperature,
                            humidity: provider.humidity,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _SectionTitle(title: 'Alert History'),
                              ),
                              if (alerts.isNotEmpty)
                                Text(
                                  '${alerts.length} logged',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _textSecondary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (alerts.isEmpty)
                            const _EmptyAlerts()
                          else
                            ...alerts.map(
                              (alert) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AlertCard(alert: alert),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1B5E20),
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({
    required this.score,
    required this.status,
    required this.color,
    required this.icon,
  });

  final double score;
  final String status;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
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
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 34),
          ),
          const SizedBox(height: 14),
          Text(
            'Overall Emission Score',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF558B2F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            score.toStringAsFixed(0),
            style: GoogleFonts.poppins(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B5E20),
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B5E20),
                    height: 1.2,
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

class _TipCard extends StatelessWidget {
  const _TipCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: const Color(0xFFF9A825), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF33691E),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorsCard extends StatelessWidget {
  const _SensorsCard({
    required this.rawGas,
    required this.temperature,
    required this.humidity,
  });

  final double rawGas;
  final double temperature;
  final double humidity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _SensorRow(
            icon: Icons.air_rounded,
            label: 'Raw Gas',
            value: '${rawGas.toStringAsFixed(0)} ppm',
            accent: const Color(0xFF2E7D32),
            soft: const Color(0xFFE8F5E9),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Colors.grey[200]),
          ),
          _SensorRow(
            icon: Icons.device_thermostat,
            label: 'Temperature',
            value: '${temperature.toStringAsFixed(1)}°C',
            accent: const Color(0xFFFB8C00),
            soft: const Color(0xFFFFF3E0),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Colors.grey[200]),
          ),
          _SensorRow(
            icon: Icons.water_drop_rounded,
            label: 'Humidity',
            value: '${humidity.toStringAsFixed(0)}%',
            accent: const Color(0xFF039BE5),
            soft: const Color(0xFFE1F5FE),
          ),
        ],
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.soft,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1B5E20),
          ),
        ),
      ],
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFC8E6C9)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 32,
              color: Color(0xFF43A047),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Alerts',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'All clear — no high-emission events logged.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF558B2F),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final EmissionAlert alert;

  @override
  Widget build(BuildContext context) {
    final severe = alert.emissionScore > 450;
    final color =
        severe ? const Color(0xFFE53935) : const Color(0xFFFF9800);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    alert.message,
                    style: GoogleFonts.poppins(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: Colors.grey[500],
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM dd, yyyy  ·  HH:mm:ss')
                          .format(alert.timestamp),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.speed_rounded, color: color, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Score ${alert.emissionScore.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
