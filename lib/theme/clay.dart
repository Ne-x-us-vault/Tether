import 'dart:math' as math;

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PASTEL CLAY — design system for Lovit
//
// A soft, tactile language: pastel pigments pressed into rounded clay forms,
// lit from the top-left so every surface has a warm highlight and a soft
// lavender shadow. Used by the auth experience and intended to spread across
// the app.
// ══════════════════════════════════════════════════════════════════════════════

class ClayPalette {
  ClayPalette._();

  // Base wash
  static const blush = Color(0xFFFDECF3);
  static const lilacMist = Color(0xFFF1EAFF);
  static const skyMist = Color(0xFFE8F3FF);
  static const cream = Color(0xFFFFF8F2);

  // Clay surfaces
  static const paper = Color(0xFFFFFBFD);
  static const paperAlt = Color(0xFFF7F1FC);
  static const wellTop = Color(0xFFEADFF7);
  static const wellBottom = Color(0xFFFCF8FF);

  // Pigments
  static const lilac = Color(0xFFB7A4E8);
  static const lilacDeep = Color(0xFF8C74C9);
  static const periwinkle = Color(0xFF9FB8F5);
  static const rose = Color(0xFFFFB7CE);
  static const peach = Color(0xFFFFC3A8);
  static const mint = Color(0xFFA9E7CF);
  static const butter = Color(0xFFFFE5A8);

  // Ink
  static const ink = Color(0xFF463A5C);
  static const inkSoft = Color(0xFF8A7DA3);
  static const inkFaint = Color(0xFFB6ACC7);

  // States
  static const error = Color(0xFFD95F7B);
  static const errorBg = Color(0xFFFFEDF2);
  static const success = Color(0xFF4FB98C);
  static const successBg = Color(0xFFE9F9F1);

  // Shadow / light
  static const shadow = Color(0xFFB9A6DD);
  static const shadowDeep = Color(0xFF8B76B8);
  static const highlight = Color(0xFFFFFFFF);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.42, 0.78, 1.0],
    colors: [blush, cream, lilacMist, skyMist],
  );

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
    colors: [Color(0xFFC4B5F2), lilac, periwinkle],
  );
}

class ClayType {
  ClayType._();

  static const String displayFamily = 'Fredoka';
  static const String bodyFamily = 'Nunito';

  /// Rounded, chunky display face — wordmark, headings, numerals.
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w600,
    Color color = ClayPalette.ink,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: displayFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Soft, highly legible UI face — labels, inputs, body copy.
  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = ClayPalette.ink,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: bodyFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
}

/// Soft, embossed wordmark for the product name.
class ClayWordmark extends StatelessWidget {
  const ClayWordmark({super.key, this.fontSize = 40, this.color = ClayPalette.ink});

  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'lovit',
      style: ClayType.display(
        fontSize,
        weight: FontWeight.w600,
        color: color,
        letterSpacing: -1.0,
      ).copyWith(
        shadows: [
          Shadow(
            color: ClayPalette.highlight.withValues(alpha: 0.9),
            offset: const Offset(0, 2),
            blurRadius: 2,
          ),
          Shadow(
            color: ClayPalette.shadowDeep.withValues(alpha: 0.35),
            offset: const Offset(0, 4),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

/// Drifting pastel pigments behind everything. Motion is slow and ambient and
/// collapses to a still frame when the platform requests reduced motion.
class PastelClayBackground extends StatefulWidget {
  const PastelClayBackground({super.key, required this.child});

  final Widget child;

  @override
  State<PastelClayBackground> createState() => _PastelClayBackgroundState();
}

class _PastelClayBackgroundState extends State<PastelClayBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  bool _motion = true;

  static const _blobs = <_Blob>[
    _Blob(ClayPalette.rose, 340, Alignment(-1.15, -1.05), Alignment(-0.75, -0.62), 0.55),
    _Blob(ClayPalette.periwinkle, 300, Alignment(1.2, -0.7), Alignment(0.7, -0.2), 0.5),
    _Blob(ClayPalette.mint, 280, Alignment(-1.0, 0.9), Alignment(-0.5, 0.45), 0.42),
    _Blob(ClayPalette.butter, 320, Alignment(1.15, 1.0), Alignment(0.6, 0.5), 0.45),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _motion = !reduceMotion;
    if (_motion) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.35;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: ClayPalette.backgroundGradient),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_controller.value);
              return Stack(
                fit: StackFit.expand,
                children: [
                  for (final b in _blobs)
                    Align(
                      alignment: Alignment.lerp(b.from, b.to, t)!,
                      child: Container(
                        width: b.size,
                        height: b.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              b.color.withValues(alpha: b.opacity),
                              b.color.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // Top sheen keeps the wash from feeling flat.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Blob {
  const _Blob(this.color, this.size, this.from, this.to, this.opacity);
  final Color color;
  final double size;
  final Alignment from;
  final Alignment to;
  final double opacity;
}

/// A raised, puffy clay slab.
class ClayPanel extends StatelessWidget {
  const ClayPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(26),
    this.radius = 34,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ClayPalette.paper,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ClayPalette.shadowDeep.withValues(alpha: 0.26),
            blurRadius: 44,
            offset: const Offset(0, 20),
            spreadRadius: -10,
          ),
          BoxShadow(
            color: ClayPalette.shadow.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(7, 10),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: ClayPalette.highlight.withValues(alpha: 0.9),
            blurRadius: 14,
            offset: const Offset(-7, -7),
            spreadRadius: -6,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A pressed-in clay well — used behind text fields.
class ClayWell extends StatelessWidget {
  const ClayWell({
    super.key,
    required this.child,
    this.focused = false,
    this.radius = 20,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final bool focused;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: focused
              ? const [Colors.white, Colors.white]
              : const [ClayPalette.wellTop, ClayPalette.wellBottom],
        ),
        border: Border(
          top: BorderSide(
            color: ClayPalette.shadowDeep.withValues(alpha: focused ? 0.16 : 0.24),
            width: 2,
          ),
          left: BorderSide(
            color: ClayPalette.shadowDeep.withValues(alpha: focused ? 0.10 : 0.15),
            width: 2,
          ),
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.95),
            width: 2,
          ),
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.95),
            width: 2,
          ),
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: ClayPalette.lilac.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: child,
    );
  }
}

/// Chunky primary clay button with a tactile press.
class ClayButton extends StatefulWidget {
  const ClayButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.icon,
    this.height = 58,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final IconData? icon;
  final double height;

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !widget.loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onTap?.call();
              }
            : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          height: widget.height,
          transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
          decoration: BoxDecoration(
            gradient: ClayPalette.primaryGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: _down || !enabled
                ? [
                    BoxShadow(
                      color: ClayPalette.shadowDeep.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: ClayPalette.shadowDeep.withValues(alpha: 0.42),
                      blurRadius: 22,
                      offset: const Offset(0, 11),
                      spreadRadius: -3,
                    ),
                    BoxShadow(
                      color: ClayPalette.lilac.withValues(alpha: 0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 6),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.45),
                      blurRadius: 6,
                      offset: const Offset(-3, -3),
                    ),
                  ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 19),
                        const SizedBox(width: 9),
                      ],
                      Text(
                        widget.label,
                        style: ClayType.body(
                          16,
                          weight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Quiet secondary action used for the sign-up toggle.
class ClayGhostButton extends StatelessWidget {
  const ClayGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ClayPalette.lilac.withValues(alpha: 0.55),
              width: 1.6,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: ClayPalette.lilacDeep, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: ClayType.body(
                    15,
                    weight: FontWeight.w700,
                    color: ClayPalette.lilacDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline error / status banner.
class ClayBanner extends StatelessWidget {
  const ClayBanner({
    super.key,
    required this.message,
    this.icon = Icons.error_outline_rounded,
    this.foreground = ClayPalette.error,
    this.background = ClayPalette.errorBg,
  });

  final String message;
  final IconData icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: foreground.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: ClayType.body(13, weight: FontWeight.w600, color: foreground, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// The hero motif: two clay pebbles leaning together with a heart resting in
/// the space they share — two people, one private place.
class ClayHeroEmblem extends StatefulWidget {
  const ClayHeroEmblem({super.key, this.size = 132});

  final double size;

  @override
  State<ClayHeroEmblem> createState() => _ClayHeroEmblemState();
}

class _ClayHeroEmblemState extends State<ClayHeroEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  bool _motion = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (_motion) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final pebble = s * 0.62;
    final heart = s * 0.30;

    return RepaintBoundary(
      child: SizedBox(
        width: s,
        height: s * 0.74,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_controller.value);
            final rise = (t - 0.5) * 6;
            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: s * 0.02,
                  bottom: 4 + rise,
                  child: _Pebble(
                    size: pebble,
                    colors: const [Color(0xFFFFCBDD), ClayPalette.rose],
                  ),
                ),
                Positioned(
                  right: s * 0.02,
                  bottom: 4 - rise,
                  child: _Pebble(
                    size: pebble,
                    colors: const [Color(0xFFCFC2F5), ClayPalette.lilac],
                  ),
                ),
                Positioned(
                  bottom: s * 0.16 + rise * 0.4,
                  child: Container(
                    width: heart,
                    height: heart,
                    decoration: BoxDecoration(
                      color: ClayPalette.paper,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ClayPalette.shadowDeep.withValues(alpha: 0.32),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                          spreadRadius: -3,
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.9),
                          blurRadius: 6,
                          offset: const Offset(-2, -2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: heart * 0.52,
                      color: ClayPalette.lilacDeep,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Pebble extends StatelessWidget {
  const _Pebble({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.42),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: ClayPalette.shadowDeep.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(4, 12),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.55),
            blurRadius: 8,
            offset: const Offset(-4, -4),
            spreadRadius: -2,
          ),
        ],
      ),
    );
  }
}

/// Small pill used for status chips (e.g. the verification email).
class ClayChip extends StatelessWidget {
  const ClayChip({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: ClayPalette.paperAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClayPalette.lilac.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: ClayPalette.lilacDeep),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: ClayType.body(13.5, weight: FontWeight.w700, color: ClayPalette.ink),
          ),
        ],
      ),
    );
  }
}

/// Gentle floating sparkle used sparingly for delight.
class ClaySparkle extends StatelessWidget {
  const ClaySparkle({super.key, this.size = 14, this.color = ClayPalette.butter});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
