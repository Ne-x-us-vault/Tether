import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/glass.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ONBOARDING SCREEN — Romantic, fit-to-page
// ══════════════════════════════════════════════════════════════════════════════
class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;

  // ── Controllers ───────────────────────────────────────────────────────────
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late AnimationController _btnController;
  late AnimationController _particleController;
  late AnimationController _shimmerController;
  late AnimationController _orbitController;
  late AnimationController _rippleController;
  late AnimationController _bgController;
  late AnimationController _flameController;
  late AnimationController _sparkleController;
  late AnimationController _heartbeatController;
  late AnimationController _staggerController;

  // ── Animations ─────────────────────────────────────────────────────────────
  late Animation<double> _glowAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _btnScale;
  late Animation<double> _shimmerAnim;
  late Animation<double> _orbitAnim;
  late Animation<double> _rippleAnim;
  late Animation<double> _bgAnim;
  late Animation<double> _flameAnim;
  late Animation<double> _sparkleAnim;
  late Animation<double> _heartbeatAnim;
  late List<Animation<double>> _staggerFade;
  late List<Animation<Offset>> _staggerSlide;

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color kBg = Color(0xFF09080E);
  static const Color kPurple = Color(0xFFC9BFFF);
  static const Color kPurpleViv = Color(0xFF9B6FFF);
  static const Color kPurpleMid = Color(0xFFAA90FF);
  static const Color kTextPrimary = Color(0xFFF2EFF9);
  static const Color kTextSub = Color(0xFFCAC5D4);
  static const Color kTextMuted = Color(0xFF938F9A);
  static const Color kRose = Color(0xFFFF9BAB);
  static const Color kRoseDim = Color(0xFFD4607A);
  static const Color kGold = Color(0xFFFFD88A);

  static const _pages = [
    _PageConfig(label: 'Begin Our Story', style: _BtnStyle.rose, caption: null),
    _PageConfig(label: 'Keep Us Safe', style: _BtnStyle.vivid, caption: null),
    _PageConfig(
      label: 'Start Journey',
      style: _BtnStyle.lavender,
      caption: 'YOUR LOVE STORY STARTS HERE',
    ),
  ];

  static const _pageBgColors = [
    Color(0xFFAA5070),
    Color(0xFF7B6FFF),
    Color(0xFFBF6FE0),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _pageController = PageController();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _btnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )..repeat();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..repeat(reverse: true);
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _glowAnim = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );
    _pulseAnim = Tween<double>(begin: 0.80, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _btnScale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _btnController, curve: Curves.easeInOut));
    _shimmerAnim = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    );
    _orbitAnim = _orbitController;
    _rippleAnim = CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    );
    _bgAnim = CurvedAnimation(parent: _bgController, curve: Curves.easeInOut);
    _flameAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flameController, curve: Curves.easeInOut),
    );
    _sparkleAnim = CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.linear,
    );
    _heartbeatAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _heartbeatController, curve: Curves.easeInOut),
    );

    _staggerFade = List.generate(5, (i) {
      final s = i * 0.10, e = (s + 0.45).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(s, e, curve: Curves.easeOut),
        ),
      );
    });
    _staggerSlide = List.generate(5, (i) {
      final s = i * 0.10, e = (s + 0.45).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.10),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(s, e, curve: Curves.easeOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    _btnController.dispose();
    _particleController.dispose();
    _shimmerController.dispose();
    _orbitController.dispose();
    _rippleController.dispose();
    _bgController.dispose();
    _flameController.dispose();
    _sparkleController.dispose();
    _heartbeatController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _staggerController
      ..reset()
      ..forward();
    _bgController
      ..reset()
      ..forward();
  }

  void _onButtonTap() {
    HapticFeedback.lightImpact();
    _btnController.forward().then((_) => _btnController.reverse());
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topInset = mq.padding.top;
    final botInset = mq.padding.bottom;
    const barBase = 136.0;
    final barHeight = barBase + botInset;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(
            child: LovitBackground(
              blurSigma: 24,
              darkOverlayOpacity: 0.52,
              vignetteOpacity: 0.24,
            ),
          ),
          // ── Morphing bg glow ──────────────────────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([_bgAnim, _glowAnim]),
            builder: (_, _) {
              final from = _currentPage > 0
                  ? _pageBgColors[_currentPage - 1]
                  : _pageBgColors[0];
              final to = _pageBgColors[_currentPage];
              final col = ColorTween(begin: from, end: to).evaluate(_bgAnim)!;
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.65),
                        radius: 1.0,
                        colors: [
                          col.withValues(alpha: 0.14 + 0.06 * _glowAnim.value),
                          kBg,
                        ],
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.7, 0.9),
                        radius: 0.7,
                        colors: [
                          kRose.withValues(alpha: 0.04 + 0.03 * _glowAnim.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Floating mini-heart particles ─────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (_, _) => CustomPaint(
                  painter: _HeartParticlePainter(_particleController.value),
                ),
              ),
            ),
          ),

          // ── PageView ──────────────────────────────────────────────────────
          Positioned.fill(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                _PageIntimacy(
                  topInset: topInset,
                  bottomPad: barHeight,
                  glowAnim: _glowAnim,
                  flameAnim: _flameAnim,
                  sparkleAnim: _sparkleAnim,
                  staggerFade: _staggerFade,
                  staggerSlide: _staggerSlide,
                ),
                _PagePrivacy(
                  topInset: topInset,
                  bottomPad: barHeight,
                  glowAnim: _glowAnim,
                  orbitAnim: _orbitAnim,
                  staggerFade: _staggerFade,
                  staggerSlide: _staggerSlide,
                ),
                _PageTogether(
                  topInset: topInset,
                  bottomPad: barHeight,
                  glowAnim: _glowAnim,
                  pulseAnim: _pulseAnim,
                  rippleAnim: _rippleAnim,
                  sparkleAnim: _sparkleAnim,
                  heartbeatAnim: _heartbeatAnim,
                  staggerFade: _staggerFade,
                  staggerSlide: _staggerSlide,
                ),
              ],
            ),
          ),

          // ── Glass bottom bar ──────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111712).withValues(alpha: 0.58),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1,
                      ),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(24, 18, 24, botInset + 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Dots ──────────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final active = _currentPage == i;
                          final passed = i < _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 360),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 28 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: active
                                  ? kRose
                                  : passed
                                  ? kRoseDim.withValues(alpha: 0.55)
                                  : kTextMuted.withValues(alpha: 0.30),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                        color: kRose.withValues(alpha: 0.55),
                                        blurRadius: 12,
                                      ),
                                    ]
                                  : [],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 18),

                      // ── CTA ───────────────────────────────────────────────
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.15),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _currentPage == 2
                            ? _SliderCTAButton(
                                key: const ValueKey('slider'),
                                glowAnim: _glowAnim,
                                shimmerAnim: _shimmerAnim,
                                onComplete: widget.onComplete ?? () {},
                              )
                            : GestureDetector(
                                key: const ValueKey('tap'),
                                onTapDown: (_) => _btnController.forward(),
                                onTapCancel: () => _btnController.reverse(),
                                onTap: _onButtonTap,
                                child: ScaleTransition(
                                  scale: _btnScale,
                                  child: AnimatedBuilder(
                                    animation: Listenable.merge([
                                      _glowAnim,
                                      _shimmerAnim,
                                    ]),
                                    builder: (_, _) {
                                      final cfg = _pages[_currentPage];
                                      LinearGradient grad;
                                      Color glowCol, textCol;
                                      switch (cfg.style) {
                                        case _BtnStyle.rose:
                                          grad = const LinearGradient(
                                            colors: [
                                              Color(0xFFE8607A),
                                              Color(0xFFC04060),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          );
                                          glowCol = kRose;
                                          textCol = Colors.white;
                                          break;
                                        case _BtnStyle.vivid:
                                          grad = const LinearGradient(
                                            colors: [
                                              Color(0xFF9B6FFF),
                                              Color(0xFF7040DF),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          );
                                          glowCol = kPurpleViv;
                                          textCol = Colors.white;
                                          break;
                                        case _BtnStyle.lavender:
                                          grad = const LinearGradient(
                                            colors: [
                                              Color(0xFFCDC8FF),
                                              Color(0xFFBAB2F5),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          );
                                          glowCol = kPurpleMid;
                                          textCol = const Color(0xFF1A1530);
                                          break;
                                      }
                                      return AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 380,
                                        ),
                                        width: double.infinity,
                                        height: 62,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            36,
                                          ),
                                          gradient: grad,
                                          boxShadow: [
                                            BoxShadow(
                                              color: glowCol.withValues(alpha: 
                                                0.42 + 0.14 * _glowAnim.value,
                                              ),
                                              blurRadius: 36,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            36,
                                          ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Positioned.fill(
                                                child: CustomPaint(
                                                  painter: _ShimmerPainter(
                                                    _shimmerAnim.value,
                                                  ),
                                                ),
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  AnimatedSwitcher(
                                                    duration: const Duration(
                                                      milliseconds: 280,
                                                    ),
                                                    transitionBuilder:
                                                        (
                                                          child,
                                                          anim,
                                                        ) => FadeTransition(
                                                          opacity: anim,
                                                          child: SlideTransition(
                                                            position:
                                                                Tween<Offset>(
                                                                  begin:
                                                                      const Offset(
                                                                        0,
                                                                        0.25,
                                                                      ),
                                                                  end: Offset
                                                                      .zero,
                                                                ).animate(anim),
                                                            child: child,
                                                          ),
                                                        ),
                                                    child: Text(
                                                      cfg.label,
                                                      key: ValueKey(cfg.label),
                                                      style: TextStyle(
                                                        color: textCol,
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: 0.2,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: textCol
                                                          .withValues(alpha: 0.14),
                                                    ),
                                                    child: Icon(
                                                      Icons
                                                          .arrow_forward_rounded,
                                                      color: textCol,
                                                      size: 17,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                      ),

                      // ── Caption (page 3 only) ─────────────────────────────
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: _currentPage == 2
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'YOUR LOVE STORY STARTS HERE',
                                  style: TextStyle(
                                    color: kRose.withValues(alpha: 0.55),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2.2,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Config ─────────────────────────────────────────────────────────────────────
class _PageConfig {
  const _PageConfig({
    required this.label,
    required this.style,
    required this.caption,
  });
  final String label;
  final _BtnStyle style;
  final String? caption;
}

enum _BtnStyle { rose, vivid, lavender }

// ── Stagger helper ─────────────────────────────────────────────────────────────
class _S extends StatelessWidget {
  const _S({required this.f, required this.s, required this.child});
  final Animation<double> f;
  final Animation<Offset> s;
  final Widget child;
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: f,
    child: SlideTransition(position: s, child: child),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// PAGE 1 — Intimacy Reimagined
// ══════════════════════════════════════════════════════════════════════════════
class _PageIntimacy extends StatelessWidget {
  const _PageIntimacy({
    required this.topInset,
    required this.bottomPad,
    required this.glowAnim,
    required this.flameAnim,
    required this.sparkleAnim,
    required this.staggerFade,
    required this.staggerSlide,
  });
  final double topInset, bottomPad;
  final Animation<double> glowAnim, flameAnim, sparkleAnim;
  final List<Animation<double>> staggerFade;
  final List<Animation<Offset>> staggerSlide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, topInset + 18, 24, bottomPad + 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _S(
            f: staggerFade[0],
            s: staggerSlide[0],
            child: _PillBadge(
              icon: Icons.favorite,
              iconColor: _OnboardingScreenState.kRose,
              label: 'CRAFTED WITH LOVE',
            ),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: _S(
              f: staggerFade[1],
              s: staggerSlide[1],
              child: _CandleCard(
                glowAnim: glowAnim,
                flameAnim: flameAnim,
                sparkleAnim: sparkleAnim,
              ),
            ),
          ),
          const SizedBox(height: 22),

          _S(
            f: staggerFade[2],
            s: staggerSlide[2],
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Intimacy ',
                    style: TextStyle(
                      color: _OnboardingScreenState.kTextPrimary,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      height: 1.05,
                    ),
                  ),
                  TextSpan(
                    text: 'Reimagined',
                    style: TextStyle(
                      color: _OnboardingScreenState.kRose,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),

          _S(
            f: staggerFade[3],
            s: staggerSlide[3],
            child: const Text(
              'A private sanctuary where love\nfinds its language.',
              style: TextStyle(
                color: _OnboardingScreenState.kTextSub,
                fontSize: 15.5,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          _S(
            f: staggerFade[4],
            s: staggerSlide[4],
            child: _PillBadge(
              icon: Icons.lock_outline_rounded,
              iconColor: _OnboardingScreenState.kPurple,
              label: 'END-TO-END ENCRYPTED',
              subtle: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Candle card ────────────────────────────────────────────────────────────────
class _CandleCard extends StatelessWidget {
  const _CandleCard({
    required this.glowAnim,
    required this.flameAnim,
    required this.sparkleAnim,
  });
  final Animation<double> glowAnim, flameAnim, sparkleAnim;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([glowAnim, sparkleAnim]),
      builder: (_, _) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: _OnboardingScreenState.kRose.withValues(alpha: 
                0.10 + 0.08 * glowAnim.value,
              ),
              blurRadius: 60,
              spreadRadius: 4,
            ),
            BoxShadow(
              color: _OnboardingScreenState.kPurpleViv.withValues(alpha: 
                0.06 * glowAnim.value,
              ),
              blurRadius: 80,
              spreadRadius: 8,
            ),
            BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 24),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(31),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.48, 1.0],
                    colors: [
                      Color(0xFFE8B0A0),
                      Color(0xFFC08070),
                      Color(0xFF1A1025),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.05),
                    radius: 0.90,
                    colors: [
                      const Color(
                        0xFFFFE0C0,
                      ).withValues(alpha: 0.32 + 0.16 * glowAnim.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 130,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xFF160E20)],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _EmberPainter(sparkleAnim.value, glowAnim.value),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 240,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned(
                      left: 72,
                      bottom: 0,
                      child: _Candle(
                        width: 22,
                        height: 85,
                        color: const Color(0xFFBF6050),
                        glowAnim: glowAnim,
                        flameAnim: flameAnim,
                        phase: 0.35,
                      ),
                    ),
                    Positioned(
                      left: 132,
                      bottom: 0,
                      child: _Candle(
                        width: 28,
                        height: 140,
                        color: const Color(0xFFA85040),
                        glowAnim: glowAnim,
                        flameAnim: flameAnim,
                        phase: 0.0,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 18,
                left: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite,
                        color: _OnboardingScreenState.kRose.withValues(alpha: 0.9),
                        size: 10,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'just for two',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Candle extends StatelessWidget {
  const _Candle({
    required this.width,
    required this.height,
    required this.color,
    required this.glowAnim,
    required this.flameAnim,
    required this.phase,
  });
  final double width, height;
  final Color color;
  final Animation<double> glowAnim, flameAnim;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([glowAnim, flameAnim]),
      builder: (_, _) {
        final flicker = math.sin((flameAnim.value + phase) * math.pi);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width * 0.9,
              height: 30,
              child: CustomPaint(
                painter: _FlamePainter(glowAnim.value, flicker),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 2,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF2A1408),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    color.withValues(alpha: 0.55),
                    color,
                    color.withValues(alpha: 0.70),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFFFFD0A0,
                    ).withValues(alpha: 0.25 + 0.20 * glowAnim.value),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter(this.glow, this.flicker);
  final double glow, flicker;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, lean = flicker * size.width * 0.12;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + lean * 0.3, size.height * 0.75),
        width: size.width * 3.0,
        height: size.height,
      ),
      Paint()
        ..color = const Color(0xFFFFD090).withValues(alpha: 0.28 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    final path = Path()
      ..moveTo(cx + lean, 0)
      ..cubicTo(
        cx + size.width * 0.75 + lean,
        size.height * 0.28,
        cx + size.width * 0.70 + lean,
        size.height * 0.65,
        cx + lean * 0.4,
        size.height,
      )
      ..cubicTo(
        cx - size.width * 0.70 + lean,
        size.height * 0.65,
        cx - size.width * 0.75 + lean,
        size.height * 0.28,
        cx + lean,
        0,
      );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFFF9020),
            const Color(0xFFFFD060),
            const Color(0xFFFFF8C0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + lean, size.height * 0.14),
        width: size.width * 0.35,
        height: size.height * 0.26,
      ),
      Paint()
        ..color = const Color(0xFFFFFFE0).withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(_FlamePainter o) => o.glow != glow || o.flicker != flicker;
}

class _EmberPainter extends CustomPainter {
  _EmberPainter(this.t, this.glow);
  final double t, glow;
  static final _rng = math.Random(42);
  static final _embers = List.generate(
    20,
    (i) => [
      _rng.nextDouble(),
      _rng.nextDouble() * 0.70,
      _rng.nextDouble(),
      1.2 + _rng.nextDouble() * 2.2,
    ],
  );
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final e in _embers) {
      p.color = _OnboardingScreenState.kGold.withValues(alpha: 
        math.sin(((t + e[2]) % 1.0) * math.pi) * glow * 0.60,
      );
      canvas.drawCircle(Offset(e[0] * size.width, e[1] * size.height), e[3], p);
    }
  }

  @override
  bool shouldRepaint(_EmberPainter o) => o.t != t;
}

// ══════════════════════════════════════════════════════════════════════════════
// PAGE 2 — Your Love, Protected
// ══════════════════════════════════════════════════════════════════════════════
class _PagePrivacy extends StatelessWidget {
  const _PagePrivacy({
    required this.topInset,
    required this.bottomPad,
    required this.glowAnim,
    required this.orbitAnim,
    required this.staggerFade,
    required this.staggerSlide,
  });
  final double topInset, bottomPad;
  final Animation<double> glowAnim, orbitAnim;
  final List<Animation<double>> staggerFade;
  final List<Animation<Offset>> staggerSlide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topInset + 14, bottom: bottomPad + 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _S(
            f: staggerFade[0],
            s: staggerSlide[0],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.center,
                child: _PillBadge(
                  icon: Icons.shield_outlined,
                  iconColor: _OnboardingScreenState.kRose,
                  label: 'YOUR LOVE IS SAFE HERE',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          _S(
            f: staggerFade[1],
            s: staggerSlide[1],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Your Love, ',
                      style: TextStyle(
                        color: _OnboardingScreenState.kTextPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.9,
                        height: 1.08,
                      ),
                    ),
                    TextSpan(
                      text: 'Protected',
                      style: TextStyle(
                        color: _OnboardingScreenState.kRose,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.9,
                        height: 1.08,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),

          _S(
            f: staggerFade[2],
            s: staggerSlide[2],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Text(
                'Your most intimate moments deserve\nthe highest protection.',
                style: TextStyle(
                  color: _OnboardingScreenState.kTextSub,
                  fontSize: 14,
                  height: 1.60,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: _S(
              f: staggerFade[3],
              s: staggerSlide[3],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: _LoveLockCard(
                    glowAnim: glowAnim,
                    orbitAnim: orbitAnim,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          _S(
            f: staggerFade[4],
            s: staggerSlide[4],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Expanded(
                      child: _FeatureBox(
                        icon: Icons.visibility_off_outlined,
                        title: 'No Tracking',
                        sub: 'We never see or sell your moments.',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _FeatureBox(
                        icon: Icons.autorenew_rounded,
                        title: 'Self-Destruct',
                        sub: 'Messages vanish after reading.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveLockCard extends StatelessWidget {
  const _LoveLockCard({required this.glowAnim, required this.orbitAnim});
  final Animation<double> glowAnim, orbitAnim;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([glowAnim, orbitAnim]),
      builder: (_, _) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09), width: 1.2),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF201828), Color(0xFF140E1E)],
          ),
          boxShadow: [
            BoxShadow(
              color: _OnboardingScreenState.kRose.withValues(alpha: 
                0.08 + 0.06 * glowAnim.value,
              ),
              blurRadius: 48,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(100, 100),
                    painter: _HeartOrbitPainter(
                      orbitAnim.value,
                      glowAnim.value,
                    ),
                  ),
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _OnboardingScreenState.kRose.withValues(alpha: 0.10),
                          _OnboardingScreenState.kRose.withValues(alpha: 0.02),
                        ],
                      ),
                      border: Border.all(
                        color: _OnboardingScreenState.kRose.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _OnboardingScreenState.kRose.withValues(alpha: 
                            0.22 * glowAnim.value,
                          ),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_outline_rounded,
                      color: _OnboardingScreenState.kRose,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: ShapeDecoration(
                color: _OnboardingScreenState.kRose.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: _OnboardingScreenState.kRose.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _OnboardingScreenState.kRose,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'END-TO-END ENCRYPTED',
                    style: TextStyle(
                      color: _OnboardingScreenState.kRose,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'End-to-End Protected',
              style: TextStyle(
                color: _OnboardingScreenState.kTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Not even we can read what you share.\nIt belongs only to the two of you.',
                style: TextStyle(
                  color: _OnboardingScreenState.kTextSub,
                  fontSize: 12.5,
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartOrbitPainter extends CustomPainter {
  _HeartOrbitPainter(this.t, this.glow);
  final double t, glow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, r = size.width / 2 - 3;
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = _OnboardingScreenState.kRose.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (int i = 0; i < 4; i++) {
      final angle = t * 2 * math.pi + i * math.pi / 2;
      final dx = cx + r * math.cos(angle), dy = cy + r * math.sin(angle);
      final alpha = (0.5 + 0.5 * math.sin(t * math.pi * 2 + i)).clamp(
        0.15,
        1.0,
      );
      canvas.drawCircle(
        Offset(dx, dy),
        7,
        Paint()
          ..color = _OnboardingScreenState.kRose.withValues(alpha: 
            0.14 * alpha * glow,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        Offset(dx, dy),
        2.8,
        Paint()
          ..color = _OnboardingScreenState.kRose.withValues(alpha: 
            0.75 + 0.25 * alpha,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_HeartOrbitPainter o) => o.t != t || o.glow != glow;
}

class _FeatureBox extends StatelessWidget {
  const _FeatureBox({
    required this.icon,
    required this.title,
    required this.sub,
  });
  final IconData icon;
  final String title, sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.2),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1828), Color(0xFF15101E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _OnboardingScreenState.kRose.withValues(alpha: 0.10),
            ),
            child: Icon(icon, color: _OnboardingScreenState.kRose, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: _OnboardingScreenState.kTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(
              color: _OnboardingScreenState.kTextSub,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PAGE 3 — Made for Two
// ══════════════════════════════════════════════════════════════════════════════
class _PageTogether extends StatelessWidget {
  const _PageTogether({
    required this.topInset,
    required this.bottomPad,
    required this.glowAnim,
    required this.pulseAnim,
    required this.rippleAnim,
    required this.sparkleAnim,
    required this.heartbeatAnim,
    required this.staggerFade,
    required this.staggerSlide,
  });
  final double topInset, bottomPad;
  final Animation<double> glowAnim,
      pulseAnim,
      rippleAnim,
      sparkleAnim,
      heartbeatAnim;
  final List<Animation<double>> staggerFade;
  final List<Animation<Offset>> staggerSlide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, topInset + 18, 24, bottomPad + 12),
      child: Column(
        children: [
          _S(
            f: staggerFade[0],
            s: staggerSlide[0],
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Made ',
                    style: TextStyle(
                      color: _OnboardingScreenState.kTextPrimary,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.6,
                      height: 1.02,
                    ),
                  ),
                  TextSpan(
                    text: 'for Two',
                    style: TextStyle(
                      color: _OnboardingScreenState.kRose,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.6,
                      height: 1.02,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),

          _S(
            f: staggerFade[1],
            s: staggerSlide[1],
            child: const Text(
              'Your own world. Just your words,\nyour moments, your love.',
              style: TextStyle(
                color: _OnboardingScreenState.kTextSub,
                fontSize: 15,
                height: 1.65,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            flex: 5,
            child: _S(
              f: staggerFade[2],
              s: staggerSlide[2],
              child: _ConnectedHeartsCard(
                glowAnim: glowAnim,
                pulseAnim: pulseAnim,
                rippleAnim: rippleAnim,
                sparkleAnim: sparkleAnim,
                heartbeatAnim: heartbeatAnim,
              ),
            ),
          ),
          const SizedBox(height: 14),

          Expanded(
            flex: 4,
            child: _S(
              f: staggerFade[3],
              s: staggerSlide[3],
              child: _RomanticChatPreview(glowAnim: glowAnim),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedHeartsCard extends StatelessWidget {
  const _ConnectedHeartsCard({
    required this.glowAnim,
    required this.pulseAnim,
    required this.rippleAnim,
    required this.sparkleAnim,
    required this.heartbeatAnim,
  });
  final Animation<double> glowAnim,
      pulseAnim,
      rippleAnim,
      sparkleAnim,
      heartbeatAnim;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        glowAnim,
        pulseAnim,
        rippleAnim,
        sparkleAnim,
        heartbeatAnim,
      ]),
      builder: (_, _) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.2),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1C1526), Color(0xFF12101C)],
          ),
          boxShadow: [
            BoxShadow(
              color: _OnboardingScreenState.kRose.withValues(alpha: 
                0.08 * glowAnim.value,
              ),
              blurRadius: 50,
              spreadRadius: 3,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(double.infinity, double.infinity),
                painter: _RomanticRipplePainter(
                  rippleAnim.value,
                  glowAnim.value,
                ),
              ),
              CustomPaint(
                size: const Size(double.infinity, double.infinity),
                painter: _HeartSparklePainter(
                  sparkleAnim.value,
                  glowAnim.value,
                ),
              ),
              CustomPaint(
                size: const Size(double.infinity, double.infinity),
                painter: _DualHeartPainter(
                  pulse: pulseAnim.value,
                  heartbeat: heartbeatAnim.value,
                  glow: glowAnim.value,
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _OnboardingScreenState.kRose.withValues(alpha: 0.70),
                  boxShadow: [
                    BoxShadow(
                      color: _OnboardingScreenState.kRose.withValues(alpha: 0.55),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DualHeartPainter extends CustomPainter {
  _DualHeartPainter({
    required this.pulse,
    required this.heartbeat,
    required this.glow,
  });
  final double pulse, heartbeat, glow;

  Path _heartPath(Offset center, double size) {
    final s = size, cx = center.dx, cy = center.dy;
    return Path()
      ..moveTo(cx, cy + s * 0.25)
      ..cubicTo(
        cx - s * 0.05,
        cy - s * 0.05,
        cx - s * 0.55,
        cy - s * 0.20,
        cx - s * 0.50,
        cy - s * 0.50,
      )
      ..cubicTo(
        cx - s * 0.50,
        cy - s * 0.85,
        cx,
        cy - s * 0.80,
        cx,
        cy - s * 0.50,
      )
      ..cubicTo(
        cx,
        cy - s * 0.80,
        cx + s * 0.50,
        cy - s * 0.85,
        cx + s * 0.50,
        cy - s * 0.50,
      )
      ..cubicTo(
        cx + s * 0.55,
        cy - s * 0.20,
        cx + s * 0.05,
        cy - s * 0.05,
        cx,
        cy + s * 0.25,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final spread = size.width * 0.27;
    final hs = size.width * 0.16 * heartbeat;

    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          _OnboardingScreenState.kRose.withValues(alpha: 0),
          _OnboardingScreenState.kRose.withValues(alpha: 0.55 * glow),
          _OnboardingScreenState.kRose.withValues(alpha: 0.55 * glow),
          _OnboardingScreenState.kRose.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromLTRB(cx - spread, cy, cx + spread, cy))
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cx - spread, cy),
      Offset(cx + spread, cy),
      linePaint,
    );

    final lC = Offset(cx - spread, cy), lP = _heartPath(lC, hs * pulse);
    canvas.drawPath(
      lP,
      Paint()
        ..color = _OnboardingScreenState.kRose.withValues(alpha: 0.18 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawPath(
      lP,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                _OnboardingScreenState.kRose.withValues(alpha: 0.9),
                _OnboardingScreenState.kRoseDim.withValues(alpha: 0.7),
              ],
            ).createShader(
              Rect.fromCenter(center: lC, width: hs * 2, height: hs * 2),
            ),
    );

    final rC = Offset(cx + spread, cy), rP = _heartPath(rC, hs * pulse);
    canvas.drawPath(
      rP,
      Paint()
        ..color = _OnboardingScreenState.kPurpleViv.withValues(alpha: 0.18 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawPath(
      rP,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                _OnboardingScreenState.kPurple.withValues(alpha: 0.9),
                _OnboardingScreenState.kPurpleViv.withValues(alpha: 0.7),
              ],
            ).createShader(
              Rect.fromCenter(center: rC, width: hs * 2, height: hs * 2),
            ),
    );
  }

  @override
  bool shouldRepaint(_DualHeartPainter o) =>
      o.pulse != pulse || o.heartbeat != heartbeat || o.glow != glow;
}

class _RomanticRipplePainter extends CustomPainter {
  _RomanticRipplePainter(this.t, this.glow);
  final double t, glow;
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, maxR = size.width * 0.55;
    for (int i = 0; i < 4; i++) {
      final phase = (t + i * 0.25) % 1.0;
      canvas.drawCircle(
        Offset(cx, cy),
        phase * maxR,
        Paint()
          ..color = _OnboardingScreenState.kRose.withValues(alpha: 
            (1 - phase) * 0.10 * glow,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(_RomanticRipplePainter o) => o.t != t;
}

class _HeartSparklePainter extends CustomPainter {
  _HeartSparklePainter(this.t, this.glow);
  final double t, glow;
  static final _rng = math.Random(77);
  static final _dots = List.generate(
    10,
    (_) => [
      _rng.nextDouble() * 0.8 + 0.1,
      _rng.nextDouble() * 0.8 + 0.1,
      _rng.nextDouble(),
      1.2 + _rng.nextDouble() * 2.0,
    ],
  );
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final d in _dots) {
      p.color = _OnboardingScreenState.kRose.withValues(alpha: 
        math.sin(((t + d[2]) % 1.0) * math.pi) * glow * 0.65,
      );
      canvas.drawCircle(Offset(d[0] * size.width, d[1] * size.height), d[3], p);
    }
  }

  @override
  bool shouldRepaint(_HeartSparklePainter o) => o.t != t;
}

class _RomanticChatPreview extends StatelessWidget {
  const _RomanticChatPreview({required this.glowAnim});
  final Animation<double> glowAnim;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowAnim,
      builder: (_, _) => Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09), width: 1.2),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C1525), Color(0xFF13101C)],
          ),
          boxShadow: [
            BoxShadow(
              color: _OnboardingScreenState.kRose.withValues(alpha: 
                0.07 + 0.05 * glowAnim.value,
              ),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _OnboardingScreenState.kRose.withValues(alpha: 0.85),
                    boxShadow: [
                      BoxShadow(
                        color: _OnboardingScreenState.kRose.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'YOUR PRIVATE SPACE',
                  style: TextStyle(
                    color: _OnboardingScreenState.kTextMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
            _ChatBubble(text: 'thinking about you 🌙', isSent: false),
            _ChatBubble(text: 'always ♡', isSent: true),
            _ChatBubble(
              text: "can't wait to see you tonight",
              isSent: false,
              reaction: '🤍',
            ),
            Row(
              children: [
                _TypingDots(glowAnim: glowAnim),
                const SizedBox(width: 8),
                Text(
                  'typing…',
                  style: TextStyle(
                    color: _OnboardingScreenState.kTextMuted,
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.isSent, this.reaction});
  final String text;
  final bool isSent;
  final String? reaction;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isSent
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            constraints: const BoxConstraints(maxWidth: 200),
            decoration: BoxDecoration(
              color: isSent ? const Color(0xFFD05068) : const Color(0xFF1E1830),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isSent ? 16 : 4),
                bottomRight: Radius.circular(isSent ? 4 : 16),
              ),
              boxShadow: isSent
                  ? [
                      BoxShadow(
                        color: _OnboardingScreenState.kRoseDim.withValues(alpha: 
                          0.35,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isSent ? Colors.white : _OnboardingScreenState.kTextSub,
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (reaction != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09),
                    width: 1,
                  ),
                ),
                child: Text(reaction!, style: const TextStyle(fontSize: 11)),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots({required this.glowAnim});
  final Animation<double> glowAnim;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowAnim,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final a =
              (math.sin((glowAnim.value + i * 0.22) * math.pi * 2) * 0.5 + 0.5)
                  .clamp(0.2, 1.0);
          return Container(
            margin: const EdgeInsets.only(right: 4),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _OnboardingScreenState.kRose.withValues(alpha: a),
            ),
          );
        }),
      ),
    );
  }
}

// ── Pill badge ─────────────────────────────────────────────────────────────────
class _PillBadge extends StatelessWidget {
  const _PillBadge({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtle = false,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: ShapeDecoration(
        color: iconColor.withValues(alpha: subtle ? 0.06 : 0.09),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: iconColor.withValues(alpha: 0.22), width: 1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 11),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: iconColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Heart particles ────────────────────────────────────────────────────────────
class _HeartParticlePainter extends CustomPainter {
  _HeartParticlePainter(this.progress);
  final double progress;

  static final _rng = math.Random(55);
  static final _pts = List.generate(
    16,
    (_) => _HP(
      x: _rng.nextDouble(),
      startY: _rng.nextDouble(),
      speed: 0.03 + _rng.nextDouble() * 0.04,
      phase: _rng.nextDouble(),
      size: 3.0 + _rng.nextDouble() * 5.0,
      drift: (_rng.nextDouble() - 0.5) * 0.03,
    ),
  );

  Path _mini(double cx, double cy, double s) => Path()
    ..moveTo(cx, cy + s * 0.25)
    ..cubicTo(
      cx - s * 0.05,
      cy - s * 0.05,
      cx - s * 0.55,
      cy - s * 0.25,
      cx - s * 0.50,
      cy - s * 0.50,
    )
    ..cubicTo(
      cx - s * 0.50,
      cy - s * 0.80,
      cx,
      cy - s * 0.75,
      cx,
      cy - s * 0.50,
    )
    ..cubicTo(
      cx,
      cy - s * 0.75,
      cx + s * 0.50,
      cy - s * 0.80,
      cx + s * 0.50,
      cy - s * 0.50,
    )
    ..cubicTo(
      cx + s * 0.55,
      cy - s * 0.25,
      cx + s * 0.05,
      cy - s * 0.05,
      cx,
      cy + s * 0.25,
    )
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final pt in _pts) {
      final t = (progress * pt.speed + pt.phase) % 1.0;
      final y = ((pt.startY - t) % 1.0 + 1.0) % 1.0;
      final x = pt.x + pt.drift * t;
      p.color = _OnboardingScreenState.kRose.withValues(alpha: 
        math.sin(t * math.pi) * 0.16,
      );
      canvas.drawPath(_mini(x * size.width, y * size.height, pt.size), p);
    }
  }

  @override
  bool shouldRepaint(_HeartParticlePainter o) => o.progress != progress;
}

class _HP {
  const _HP({
    required this.x,
    required this.startY,
    required this.speed,
    required this.phase,
    required this.size,
    required this.drift,
  });
  final double x, startY, speed, phase, size, drift;
}

// ── Button shimmer ─────────────────────────────────────────────────────────────
class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final x = -size.width * 0.3 + size.width * 1.6 * t;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment((-1 + 2 * (x / size.width)).clamp(-1.5, 1.5), -1),
          end: Alignment(
            (-1 + 2 * (x / size.width) + 0.45).clamp(-1.5, 1.5),
            1,
          ),
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.11),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShimmerPainter o) => o.t != t;
}

// ══════════════════════════════════════════════════════════════════════════════
// Slide-to-confirm CTA — FIXED: no red flicker
// ══════════════════════════════════════════════════════════════════════════════
class _SliderCTAButton extends StatefulWidget {
  const _SliderCTAButton({
    super.key,
    required this.glowAnim,
    required this.shimmerAnim,
    required this.onComplete,
  });
  final Animation<double> glowAnim, shimmerAnim;
  final VoidCallback onComplete;

  @override
  State<_SliderCTAButton> createState() => _SliderCTAButtonState();
}

class _SliderCTAButtonState extends State<_SliderCTAButton>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  bool _completed = false;

  late AnimationController _snapBack;
  late Animation<double> _snapAnim;

  @override
  void initState() {
    super.initState();
    _snapBack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _snapAnim = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _snapBack, curve: Curves.elasticOut));
    // FIX: clamp the animated progress to [0,1] to prevent negative values
    _snapBack.addListener(() {
      setState(() {
        _progress = _snapAnim.value.clamp(0.0, 1.0);
      });
    });
  }

  @override
  void dispose() {
    _snapBack.dispose();
    super.dispose();
  }

  void _startSnapBack() {
    _snapAnim = Tween<double>(
      begin: _progress,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _snapBack, curve: Curves.elasticOut));
    _snapBack
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    const double height = 62.0;
    const double thumbSize = 50.0;
    const double padding = 6.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth - thumbSize - padding * 2;
        final thumbLeft = padding + _progress * trackWidth;
        // FIX: ensure the gradient overlay width never becomes negative
        final gradientWidth = (thumbLeft + thumbSize * 0.5).clamp(
          0.0,
          double.infinity,
        );

        return AnimatedBuilder(
          animation: Listenable.merge([widget.glowAnim, widget.shimmerAnim]),
          builder: (_, _) => Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              gradient: const LinearGradient(
                colors: [Color(0xFFCDC8FF), Color(0xFFBAB2F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _OnboardingScreenState.kPurpleMid.withValues(alpha: 
                    0.42 + 0.14 * widget.glowAnim.value,
                  ),
                  blurRadius: 36,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ShimmerPainter(widget.shimmerAnim.value),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: gradientWidth, // clamped width
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _OnboardingScreenState.kPurpleViv.withValues(alpha: 
                              0.32 * _progress,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: (1.0 - _progress * 2.5).clamp(0.0, 1.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ...List.generate(
                              3,
                              (i) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  color: const Color(
                                    0xFF1A1530,
                                  ).withValues(alpha: 0.18 + i * 0.14),
                                  size: 20,
                                ),
                              ),
                            ).reversed,
                            const SizedBox(width: thumbSize + padding * 2 + 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: (1.0 - _progress * 2.0).clamp(0.0, 1.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(width: thumbSize * 0.5),
                            Text(
                              'Slide to Start Journey',
                              style: TextStyle(
                                color: Color(0xFF1A1530),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: thumbLeft,
                    top: (height - thumbSize) / 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) {
                        if (_completed) return;
                        _snapBack.stop();
                        setState(() {
                          _progress =
                              ((_progress * trackWidth + details.delta.dx) /
                                      trackWidth)
                                  .clamp(0.0, 1.0);
                        });
                        if (_progress >= 0.88) {
                          setState(() {
                            _progress = 1.0;
                            _completed = true;
                          });
                          HapticFeedback.mediumImpact();
                          Future.delayed(
                            const Duration(milliseconds: 340),
                            widget.onComplete,
                          );
                        }
                      },
                      onHorizontalDragEnd: (_) {
                        if (!_completed) _startSnapBack();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: thumbSize,
                        height: thumbSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _completed
                              ? _OnboardingScreenState.kPurpleViv
                              : const Color(0xFF1A1530),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.30),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                            if (_completed)
                              BoxShadow(
                                color: _OnboardingScreenState.kPurpleViv
                                    .withValues(alpha: 0.55),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                        child: Icon(
                          _completed
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          color: _completed
                              ? Colors.white
                              : _OnboardingScreenState.kPurple,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
