import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EcoDriveLogo extends StatelessWidget {
  const EcoDriveLogo({
    super.key,
    this.size = 88,
    this.showWordmark = true,
    this.showTagline = false,
  });

  final double size;
  final bool showWordmark;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'lib/assets/logo.png',
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.eco_rounded,
            size: size,
            color: const Color(0xFF2E7D32),
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Eco',
                  style: GoogleFonts.poppins(
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1B5E20),
                    letterSpacing: 0.2,
                  ),
                ),
                TextSpan(
                  text: 'Drive',
                  style: GoogleFonts.poppins(
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF8BC34A),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (showTagline) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 1.2,
                color: const Color(0xFFA5D6A7),
              ),
              const SizedBox(width: 10),
              Text(
                'Vehicle Emission Monitoring System',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF558B2F),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 1.2,
                color: const Color(0xFFA5D6A7),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
