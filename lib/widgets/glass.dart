import 'dart:ui';
import 'package:flutter/material.dart';

const String kLovitBackgroundAsset = 'assets/images/background.jpg';

class LovitBackground extends StatelessWidget {
  const LovitBackground({
    super.key,
    this.blurSigma = 14, // Optimized from 24
    this.darkOverlayOpacity = 0.58,
    this.vignetteOpacity = 0.30,
    this.imageScale = 1.10,
    this.alignment = Alignment.center,
  });

  final double blurSigma;
  final double darkOverlayOpacity;
  final double vignetteOpacity;
  final double imageScale;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: imageScale,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: Image.asset(
                kLovitBackgroundAsset,
                fit: BoxFit.cover,
                alignment: alignment,
              ),
            ),
          ),
          // Deep dark gradient overlay
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF070B11).withValues(alpha: darkOverlayOpacity),
                  const Color(0xFF090D14).withValues(alpha: darkOverlayOpacity + 0.06),
                  const Color(0xFF040608).withValues(alpha: darkOverlayOpacity + 0.12),
                ],
              ),
            ),
          ),
          // Aurora animated glows
          const AnimatedAurora(
            color: Color(0xFFC9BFFF),
            alignment: Alignment(-0.8, -0.7),
            size: 400,
          ),
          const AnimatedAurora(
            color: Color(0xFFFF9BAB),
            alignment: Alignment(0.9, 0.4),
            size: 350,
          ),
          // Vignette
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.15, -0.8),
                radius: 1.4,
                colors: [
                  Colors.transparent,
                  const Color(0xFF010204).withValues(alpha: vignetteOpacity),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedAurora extends StatefulWidget {
  const AnimatedAurora({
    super.key,
    required this.color,
    required this.alignment,
    required this.size,
  });
  final Color color;
  final Alignment alignment;
  final double size;

  @override
  State<AnimatedAurora> createState() => _AnimatedAuroraState();
}

class _AnimatedAuroraState extends State<AnimatedAurora>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Alignment> _pos;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    _opacity = Tween<double>(begin: 0.04, end: 0.12).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    _pos = Tween<Alignment>(
      begin: widget.alignment,
      end: widget.alignment + const Alignment(0.1, 0.1),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Align(
        alignment: _pos.value,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.color.withValues(alpha: _opacity.value),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding = const EdgeInsets.all(20),
    this.blurSigma = 14, // Optimized from 24
    this.tintColor,
    this.borderColor,
    this.shadowColor,
    this.showDoubleBorder = true,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final double blurSigma;
  final Color? tintColor;
  final Color? borderColor;
  final Color? shadowColor;
  final bool showDoubleBorder;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: shadowColor ?? Colors.black.withValues(alpha: 0.22),
              blurRadius: 32,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.6, 1.0],
                  colors: [
                    (tintColor ?? const Color(0xFFFFFFFF)).withValues(alpha: 0.08),
                    (tintColor ?? const Color(0xFFFFFFFF)).withValues(alpha: 0.03),
                    (tintColor ?? const Color(0xFFFFFFFF)).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: borderColor ?? Colors.white.withValues(alpha: 0.14),
                  width: 1.2,
                ),
              ),
              child: Stack(
                children: [
                  if (showDoubleBorder)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(borderRadius - 1),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.04),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
