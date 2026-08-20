import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../services/supabase_service.dart';

const _kBgDark = Color(0xFF09090B);
const _kCardBg = Color(0xFF131318);
const _kCardBgLight = Color(0xFF1a1a1f);
const _kPurple = Color(0xFF8B5CF6);
const _kPurpleViv = Color(0xFFC084FC);
const _kPink = Color(0xFFF43F5E);
const _kPinkViv = Color(0xFFFB7185);
const _kCyan = Color(0xFF06b6d4);
const _kText = Color(0xFFE4E1E9);
const _kTextSub = Color(0xFFC9C4D1);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabase = SupabaseService();

  bool _isLoading = false;
  bool _isSignUp = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _awaitingEmailVerification = false;
  String? _pendingSignupEmail;
  bool _emailFocused = false;
  bool _passwordFocused = false;

  late AnimationController _animController;
  late AnimationController _floatController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _rotateAnim;

  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Floating animation controller (continuous)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _floatAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _rotateAnim = Tween<double>(
      begin: 0,
      end: 2 * 3.14159,
    ).animate(CurvedAnimation(parent: _floatController, curve: Curves.linear));

    _animController.forward();

    _videoController = VideoPlayerController.asset(
      'assets/login_screen/animate_girl.mp4',
    )
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..initialize().then((_) {
        _videoController.setLooping(true);
        _videoController.setVolume(0);
        _videoController.play();
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    _floatController.dispose();
    _videoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);
    _errorMessage = null;

    try {
      if (_isSignUp) {
        await _supabase.signUpWithEmail(email: email, password: password);
        // After signup, show verification screen
        if (mounted) {
          setState(() {
            _awaitingEmailVerification = true;
            _pendingSignupEmail = email;
            _passwordController.clear();
          });
        }
      } else {
        await _supabase.signInWithEmail(email: email, password: password);

        // Check if user profile exists
        final profile = await _supabase.getMyProfile();
        if (profile == null) {
          // The router can redirect immediately after auth state changes,
          // so ensure the profile row exists even if this screen unmounts.
          final user = _supabase.currentUser;
          if (user != null) {
            await _supabase.upsertProfile(
              UserProfile(
                id: user.id,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
          }
        }

        // Navigate into the app
        if (mounted) {
          context.go('/home');
        }
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'An error occurred: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_pendingSignupEmail == null) return;

    setState(() => _isLoading = true);

    try {
      // Simply sign up again - this will resend the email
      await _supabase.signUpWithEmail(
        email: _pendingSignupEmail!,
        password: _passwordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent again! Check your inbox.'),
            backgroundColor: _kPurple,
          ),
        );
      }
    } catch (e) {
      setState(
        () => _errorMessage = 'Email already registered. Try signing in.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _backToLogin() {
    setState(() {
      _awaitingEmailVerification = false;
      _pendingSignupEmail = null;
      _isSignUp = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgDark,
      body: Stack(
        children: [
          // Background decorative elements
          Positioned(
            top: -100,
            right: -50,
            child: Transform.rotate(
              angle: _rotateAnim.value,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kPurple.withValues(alpha: 0.15),
                      _kPurple.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Transform.rotate(
              angle: -_rotateAnim.value * 0.5,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_kPink.withValues(alpha: 0.1), _kPink.withValues(alpha: 0.0)],
                  ),
                ),
              ),
            ),
          ),

          // Main content
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: _awaitingEmailVerification
                      ? _buildEmailVerificationUI()
                      : _buildLoginUI(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.08),

        // Animated Girl Video
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: _videoController.value.isInitialized
              ? SizedBox(
                  width: 200,
                  height: 200,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  ),
                )
              : Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_kPurpleViv.withValues(alpha: 0.3), _kPink.withValues(alpha: 0.2)],
                    ),
                  ),
                  child: Center(
                    child: Icon(Icons.favorite_rounded, size: 50, color: _kPurpleViv),
                  ),
                ),
        ),

        const SizedBox(height: 32),

        // Title with gradient
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [_kText, _kPurpleViv],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            _isSignUp ? 'Create Account' : 'Welcome Back',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Subtitle with better styling
        Text(
          _isSignUp
              ? 'Join Lovit to connect with your partner'
              : 'Log in to your Lovit account',
          style: TextStyle(
            fontSize: 15,
            color: _kTextSub,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 52),

        // Form Card with 3D effect
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX((_floatAnim.value - 0.5) * 0.1),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _kCardBgLight.withValues(alpha: 0.8),
                  _kCardBg.withValues(alpha: 0.6),
                ],
              ),
              border: Border.all(color: _kPurple.withValues(alpha: 0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: _kPurple.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Column(
                  children: [
                    // Email Field
                    _build3DTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                      isFocused: _emailFocused,
                      onFocusChange: (focused) {
                        setState(() => _emailFocused = focused);
                      },
                      icon: Icons.mail_outline_rounded,
                    ),

                    const SizedBox(height: 24),

                    // Password Field
                    _build3DTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Enter your password',
                      obscureText: _obscurePassword,
                      onFocusChange: (focused) {
                        setState(() => _passwordFocused = focused);
                      },
                      isFocused: _passwordFocused,
                      enabled: !_isLoading,
                      icon: Icons.lock_outline_rounded,
                      suffixIcon: GestureDetector(
                        onTap: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        child: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: _kTextSub,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Error Message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _kPinkViv.withValues(alpha: 0.08),
                          border: Border.all(
                            color: _kPinkViv.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _kPink.withValues(alpha: 0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: _kPinkViv,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: _kPinkViv,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Auth Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Animate3DButton(
                        onPressed: _isLoading ? null : _handleAuth,
                        isLoading: _isLoading,
                        label: _isSignUp ? 'Create Account' : 'Log In',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Toggle Sign Up / Log In with 3D effect
        GestureDetector(
          onTap: _isLoading
              ? null
              : () {
                  setState(() => _isSignUp = !_isSignUp);
                  _errorMessage = null;
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kPurple.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _kPurple.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: _isSignUp
                        ? 'Already have an account? '
                        : "Don't have an account? ",
                    style: const TextStyle(
                      color: _kTextSub,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: _isSignUp ? 'Log In' : 'Sign Up',
                    style: const TextStyle(
                      color: _kPurpleViv,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(height: MediaQuery.of(context).size.height * 0.05),
      ],
    );
  }

  Widget _buildEmailVerificationUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.08),

        // Animated 3D Envelope Icon
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY((_floatAnim.value - 0.5) * 0.6),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kCyan.withValues(alpha: 0.3), _kPurpleViv.withValues(alpha: 0.3)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _kCyan.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Icon(Icons.mail_outline_rounded, size: 60, color: _kCyan),
            ),
          ),
        ),

        const SizedBox(height: 40),

        // Title with gradient
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [_kText, _kCyan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            'Verify Your Email',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Email display with better styling
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kCyan.withValues(alpha: 0.1), _kPurple.withValues(alpha: 0.05)],
            ),
            border: Border.all(color: _kCyan.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Text(
            _pendingSignupEmail ?? '',
            style: const TextStyle(
              fontSize: 15,
              color: _kCyan,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 48),

        // Instructions Card with 3D effect
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX((_floatAnim.value - 0.5) * 0.1),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _kCardBgLight.withValues(alpha: 0.8),
                  _kCardBg.withValues(alpha: 0.6),
                ],
              ),
              border: Border.all(color: _kCyan.withValues(alpha: 0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: _kCyan.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                _kCyan.withValues(alpha: 0.3),
                                _kCyan.withValues(alpha: 0.1),
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: _kCyan,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Check Your Inbox',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _kText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'We sent a verification link to your email. Click the link to confirm your address.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _kTextSub,
                                  height: 1.6,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Error Message
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kPinkViv.withValues(alpha: 0.08),
              border: Border.all(color: _kPinkViv.withValues(alpha: 0.5), width: 1.2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: _kPink.withValues(alpha: 0.1), blurRadius: 10),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.warning_rounded, color: _kPinkViv, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: _kPinkViv,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Resend Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Animate3DButton(
            onPressed: _isLoading ? null : _resendVerificationEmail,
            isLoading: _isLoading,
            label: 'Resend Verification Email',
          ),
        ),

        const SizedBox(height: 16),

        // Back Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: GestureDetector(
            onTap: _isLoading ? null : _backToLogin,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _kTextSub.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Back to Login',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kTextSub,
                  ),
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: MediaQuery.of(context).size.height * 0.05),
      ],
    );
  }

  Widget _build3DTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isFocused,
    required Function(bool) onFocusChange,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isFocused ? _kPurpleViv : _kTextSub,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(isFocused ? 0.05 : 0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isFocused
                    ? [_kCardBgLight.withValues(alpha: 1), _kCardBg.withValues(alpha: 0.8)]
                    : [_kCardBg.withValues(alpha: 0.6), _kCardBg.withValues(alpha: 0.4)],
              ),
              border: Border.all(
                color: isFocused
                    ? _kPurpleViv.withValues(alpha: 0.6)
                    : _kPurple.withValues(alpha: 0.2),
                width: isFocused ? 2 : 1.5,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: _kPurple.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Focus(
              onFocusChange: onFocusChange,
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                enabled: enabled,
                style: const TextStyle(
                  color: _kText,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: _kTextSub.withValues(alpha: 0.4),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: Icon(
                      icon,
                      color: isFocused
                          ? _kPurpleViv
                          : _kTextSub.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ),
                  suffixIcon: suffixIcon != null
                      ? Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: suffixIcon,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// 3D Animated button component
class Animate3DButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const Animate3DButton({
    super.key,
    this.onPressed,
    required this.isLoading,
    required this.label,
  });

  @override
  State<Animate3DButton> createState() => _Animate3DButtonState();
}

class _Animate3DButtonState extends State<Animate3DButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _depthAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _depthAnim = Tween<double>(
      begin: 0,
      end: 0.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return ScaleTransition(
      scale: _scaleAnim,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(_depthAnim.value),
        child: GestureDetector(
          onTapDown: isDisabled ? null : (_) => _controller.forward(),
          onTapUp: isDisabled
              ? null
              : (_) {
                  _controller.reverse();
                  widget.onPressed?.call();
                },
          onTapCancel: isDisabled ? null : () => _controller.reverse(),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDisabled
                    ? [
                        _kPurpleViv.withValues(alpha: 0.3),
                        _kPurpleViv.withValues(alpha: 0.15),
                      ]
                    : [_kPurpleViv, _kPurple.withValues(alpha: 0.8)],
              ),
              border: Border.all(
                color: isDisabled
                    ? _kPurple.withValues(alpha: 0.2)
                    : _kPurpleViv.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: isDisabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: _kPurpleViv.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: _kPurple.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                  child: Center(
                    child: widget.isLoading
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDisabled ? _kText.withValues(alpha: 0.5) : _kText,
                              ),
                            ),
                          )
                        : Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDisabled
                                  ? _kText.withValues(alpha: 0.5)
                                  : _kText,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Glass button reusable component (kept for backwards compatibility if needed)
class GlassButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color bgColor;
  final Color borderColor;

  const GlassButton({
    super.key,
    this.onPressed,
    required this.child,
    this.bgColor = _kPurpleViv,
    this.borderColor = _kPurple,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => _controller.forward(),
        onTapUp: isDisabled
            ? null
            : (_) {
                _controller.reverse();
                widget.onPressed?.call();
              },
        onTapCancel: isDisabled ? null : () => _controller.reverse(from: 0.5),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.bgColor.withValues(alpha: isDisabled ? 0.4 : 0.8),
                widget.bgColor.withValues(alpha: isDisabled ? 0.2 : 0.5),
              ],
            ),
            border: Border.all(
              color: widget.borderColor.withValues(alpha: isDisabled ? 0.2 : 0.4),
              width: 1.5,
            ),
            boxShadow: isDisabled
                ? []
                : [
                    BoxShadow(
                      color: widget.bgColor.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  ),
                ),
                child: Center(
                  child: DefaultTextStyle(
                    style: const TextStyle(color: _kText),
                    child: Opacity(
                      opacity: isDisabled ? 0.5 : 1.0,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
