import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class DriverScoreGauge extends StatelessWidget {
  final double score;
  final String status;
  final bool isLoading;

  const DriverScoreGauge({
    super.key,
    required this.score,
    required this.status,
    this.isLoading = false,
  });

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

  @override
  Widget build(BuildContext context) {
    final badgeColor = _statusColor(status);
    final clamped = score.clamp(0.0, 500.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 155,
          width: double.infinity,
          child: SfRadialGauge(
            axes: <RadialAxis>[
              RadialAxis(
                minimum: 0,
                maximum: 500,
                startAngle: 180,
                endAngle: 0,
                showTicks: false,
                showLabels: true,
                labelsPosition: ElementsPosition.outside,
                labelOffset: 10,
                canScaleToFit: true,
                radiusFactor: 0.98,
                interval: 500,
                axisLabelStyle: const GaugeTextStyle(
                  color: Color(0xFF2E7D32),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                axisLineStyle: const AxisLineStyle(
                  thickness: 0.2,
                  thicknessUnit: GaugeSizeUnit.factor,
                  color: Color(0xFFE8F5E9),
                ),
                ranges: <GaugeRange>[
                  GaugeRange(
                    startValue: 0,
                    endValue: 125,
                    color: const Color(0xFF66BB6A),
                    startWidth: 0.2,
                    endWidth: 0.2,
                    sizeUnit: GaugeSizeUnit.factor,
                  ),
                  GaugeRange(
                    startValue: 125,
                    endValue: 250,
                    color: const Color(0xFFFFEB3B),
                    startWidth: 0.2,
                    endWidth: 0.2,
                    sizeUnit: GaugeSizeUnit.factor,
                  ),
                  GaugeRange(
                    startValue: 250,
                    endValue: 375,
                    color: const Color(0xFFFF9800),
                    startWidth: 0.2,
                    endWidth: 0.2,
                    sizeUnit: GaugeSizeUnit.factor,
                  ),
                  GaugeRange(
                    startValue: 375,
                    endValue: 500,
                    color: const Color(0xFFE53935),
                    startWidth: 0.2,
                    endWidth: 0.2,
                    sizeUnit: GaugeSizeUnit.factor,
                  ),
                ],
                pointers: <GaugePointer>[
                  NeedlePointer(
                    value: clamped,
                    enableAnimation: true,
                    animationDuration: 900,
                    needleLength: 0.62,
                    needleStartWidth: 1,
                    needleEndWidth: 5,
                    needleColor: const Color(0xFF1B5E20),
                    knobStyle: const KnobStyle(
                      color: Color(0xFF2E7D32),
                      knobRadius: 0.08,
                      borderColor: Colors.white,
                      borderWidth: 0.025,
                    ),
                    tailStyle: const TailStyle(
                      length: 0.14,
                      width: 4,
                      color: Color(0xFF81C784),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF2E7D32),
              ),
            ),
          )
        else ...[
          Text(
            'Emission Level',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF558B2F),
            ),
          ),
          Text(
            clamped.toStringAsFixed(0),
            style: GoogleFonts.poppins(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B5E20),
              height: 1.05,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
