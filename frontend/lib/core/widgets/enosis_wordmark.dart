import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A styled "E" mark shown ONLY when assets/branding/enosis_logo.png is
/// missing (see Image.asset's errorBuilder on Splash/Login). This is
/// deliberately designed to look like an intentional brand mark, in your
/// actual brand colors — not a generic broken-image icon — so the app
/// still looks finished while you add the real PNG file.
///
/// Once assets/branding/enosis_logo.png exists, this never renders again.
class EnosisWordmark extends StatelessWidget {
  final double size;
  /// true = for use on a dark/navy background (Splash); false = for use
  /// on a light background (Login).
  final bool onDarkBackground;

  const EnosisWordmark({super.key, this.size = 100, this.onDarkBackground = true});

  @override
  Widget build(BuildContext context) {
    final foreground = onDarkBackground ? Colors.white : AppColors.primary;
    final background = onDarkBackground ? Colors.white.withOpacity(0.12) : AppColors.primary.withOpacity(0.08);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: foreground.withOpacity(0.6), width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        'E',
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}
