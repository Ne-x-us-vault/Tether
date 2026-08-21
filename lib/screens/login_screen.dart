import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

const _kClayPurple = Color(0xFF7C3AED);
const _kClayLight = Color(0xFFA78BFA);
const _kClaySurface = Color(0xFFF0E6FF);
const _kClayShadowDark = Color(0xFF5B21B6);
const _kClayShadowLight = Color(0xFFFFFFFF);
const _kClayHighlight = Color(0xFFF5F0FF);
const _kInputFill = Color(0xFFE8DCFA);
const _kInputFillFocused = Color(0xFFFFFFFF);
const _kTextDark = Color(0xFF2E1065);
const _kTextMuted = Color(0xFF8B7AA8);
const _kWhite = Color(0xFFFFFFFF);
const _kError = Color(0xFFEF4444);
const _kErrorBg = Color(0xFFFEE2E2);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final Player _player;
  late final VideoController _videoController;
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

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _player = Player();
    _videoController = VideoController(_player);
    _initVideo();
  }

  Future<void> _initVideo() async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/login_video_v2.mp4');
    if (!await file.exists()) {
      final data = await rootBundle.load(
        'assets/login_screen/VN20260821_230619.mp4',
      );
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
    await _player.open(Media(file.path));
    await _player.setVolume(0);
    await _player.setPlaylistMode(PlaylistMode.loop);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _player.dispose();
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
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      if (_isSignUp) {
        await _supabase.signUpWithEmail(email: email, password: password);
        if (mounted) {
          setState(() {
            _awaitingEmailVerification = true;
            _pendingSignupEmail = email;
            _passwordController.clear();
          });
        }
      } else {
        await _supabase.signInWithEmail(email: email, password: password);
        final profile = await _supabase.getMyProfile();
        if (profile == null) {
          final user = _supabase.currentUser;
          if (user != null) {
            await _supabase.upsertProfile(
              UserProfile(id: user.id, createdAt: DateTime.now(), updatedAt: DateTime.now()),
            );
          }
        }
        if (mounted) context.go('/home');
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'An error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_pendingSignupEmail == null) return;
    setState(() => _isLoading = true);
    try {
      await _supabase.signUpWithEmail(
        email: _pendingSignupEmail!,
        password: _passwordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent! Check your inbox.'), backgroundColor: _kClayPurple),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Email already registered. Try signing in.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Video(controller: _videoController, controls: NoVideoControls, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x221A0E3E), Color(0x991A0E3E), Color(0xF20F0726)],
                  stops: [0.0, 0.25, 0.55, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(child: _awaitingEmailVerification ? _buildEmailVerificationUI() : _buildLoginUI()),
        ],
      ),
    );
  }

  Widget _buildLoginUI() {
    return Column(
      children: [
        const Spacer(flex: 3),
        _ClayCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ClayInput(
                label: 'Email', hint: 'you@example.com',
                icon: Icons.mail_outline_rounded, controller: _emailController,
                keyboardType: TextInputType.emailAddress, isFocused: _emailFocused,
                enabled: !_isLoading, onFocusChange: (f) => setState(() => _emailFocused = f),
              ),
              const SizedBox(height: 16),
              _ClayInput(
                label: 'Password', hint: 'Enter your password',
                icon: Icons.lock_outline_rounded, controller: _passwordController,
                obscureText: _obscurePassword, isFocused: _passwordFocused,
                enabled: !_isLoading, onFocusChange: (f) => setState(() => _passwordFocused = f),
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: _kTextMuted, size: 20),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _ClayError(message: _errorMessage!),
              ],
              const SizedBox(height: 16),
              _ClayButton(
                label: _isSignUp ? 'Create Account' : 'Log In',
                onPressed: _isLoading ? null : _handleAuth,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _isLoading ? null : () { setState(() { _isSignUp = !_isSignUp; _errorMessage = null; }); },
          child: _ClayPill(
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                  style: TextStyle(color: _kTextMuted, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const TextSpan(text: 'Sign Up', style: TextStyle(color: _kClayPurple, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
        const Spacer(flex: 1),
      ],
    );
  }

  Widget _buildEmailVerificationUI() {
    return Column(
      children: [
        const Spacer(flex: 3),
        _ClayIconBubble(icon: Icons.mark_email_read_outlined),
        const SizedBox(height: 28),
        Text(
          'Check Your Inbox',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _kWhite, letterSpacing: -0.5, shadows: [Shadow(color: _kClayPurple.withValues(alpha: 0.6), blurRadius: 24)]),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: _kClayPurple.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(16)),
          child: Text(_pendingSignupEmail ?? '', style: const TextStyle(fontSize: 14, color: _kClayLight, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            'We sent a verification link. Click the link to confirm your address.',
            style: TextStyle(fontSize: 13, color: _kWhite.withValues(alpha: 0.6), height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        if (_errorMessage != null) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _ClayError(message: _errorMessage!)),
          const SizedBox(height: 16),
        ],
        _ClayButton(label: 'Resend Email', onPressed: _isLoading ? null : _resendVerificationEmail, isLoading: _isLoading),
        const SizedBox(height: 12),
        _ClayButton(label: 'Back to Login', onPressed: _isLoading ? null : _backToLogin, isLoading: false, outlined: true),
        const Spacer(flex: 1),
      ],
    );
  }
}

// Real Claymorphism widgets — soft, puffy, tactile clay feel

class _ClayCard extends StatelessWidget {
  final Widget child;
  const _ClayCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: _kClaySurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _kClayHighlight, width: 2),
        boxShadow: [
          BoxShadow(color: _kClayShadowDark.withValues(alpha: 0.35), blurRadius: 32, offset: const Offset(0, 14), spreadRadius: -4),
          BoxShadow(color: _kClayShadowDark.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(4, 6)),
          BoxShadow(color: _kClayShadowLight, blurRadius: 8, offset: const Offset(-4, -4), spreadRadius: -2),
        ],
      ),
      child: child,
    );
  }
}

class _ClayIconBubble extends StatelessWidget {
  final IconData icon;
  const _ClayIconBubble({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: _kClayPurple,
        shape: BoxShape.circle,
        border: Border.all(color: _kClayHighlight.withValues(alpha: 0.5), width: 2.5),
        boxShadow: [
          BoxShadow(color: _kClayShadowDark.withValues(alpha: 0.4), blurRadius: 28, offset: const Offset(0, 10), spreadRadius: -6),
          BoxShadow(color: _kClayShadowLight.withValues(alpha: 0.6), blurRadius: 6, offset: const Offset(-3, -3), spreadRadius: -1),
          BoxShadow(color: _kClayPurple.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 4), spreadRadius: 8),
        ],
      ),
      child: Icon(icon, size: 40, color: _kWhite),
    );
  }
}

class _ClayPill extends StatelessWidget {
  final Widget child;
  const _ClayPill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: _kClaySurface.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kClayHighlight.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(color: _kClayShadowDark.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6)),
          BoxShadow(color: _kClayShadowLight.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(-2, -2)),
        ],
      ),
      child: child,
    );
  }
}

class _ClayInput extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool isFocused;
  final bool enabled;
  final Function(bool) onFocusChange;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  const _ClayInput({
    required this.label, required this.hint, required this.icon,
    required this.controller, required this.isFocused, required this.enabled,
    required this.onFocusChange, this.keyboardType, this.obscureText = false, this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isFocused ? _kClayPurple : _kTextMuted, letterSpacing: 0.6)),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: isFocused ? _kInputFillFocused : _kInputFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isFocused ? _kClayPurple.withValues(alpha: 0.4) : Colors.transparent, width: 1.5),
            boxShadow: [
              BoxShadow(color: _kClayShadowDark.withValues(alpha: isFocused ? 0.15 : 0.1), blurRadius: isFocused ? 10 : 6, offset: const Offset(3, 3)),
              BoxShadow(color: _kClayHighlight, blurRadius: 4, offset: const Offset(-2, -2), spreadRadius: -1),
            ],
          ),
          child: Focus(
            onFocusChange: onFocusChange,
            child: TextField(
              controller: controller, keyboardType: keyboardType,
              obscureText: obscureText, enabled: enabled,
              style: const TextStyle(color: _kTextDark, fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: _kTextMuted.withValues(alpha: 0.5), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 10),
                  child: Icon(icon, color: isFocused ? _kClayPurple : _kTextMuted, size: 20),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                suffixIcon: suffixIcon != null ? Padding(padding: const EdgeInsets.only(right: 16), child: suffixIcon) : null,
                suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClayButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;

  const _ClayButton({required this.label, required this.onPressed, this.isLoading = false, this.outlined = false});

  @override
  State<_ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<_ClayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: isDisabled ? null : (_) { setState(() => _pressed = false); widget.onPressed?.call(); },
      onTapCancel: isDisabled ? null : () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        height: 56,
        decoration: widget.outlined
            ? BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _kClaySurface.withValues(alpha: 0.4), width: 2),
                boxShadow: [
                  BoxShadow(color: _kClayShadowDark.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              )
            : BoxDecoration(
                color: _kClayPurple,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _kClayHighlight.withValues(alpha: 0.3), width: 1.5),
                boxShadow: isDisabled
                    ? [BoxShadow(color: _kClayShadowDark.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))]
                    : [
                        BoxShadow(color: _kClayShadowDark.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -2),
                        BoxShadow(color: _kClayPurple.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 4), spreadRadius: 6),
                        BoxShadow(color: _kClayShadowLight.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(-2, -2)),
                      ],
              ),
        child: Center(
          child: widget.isLoading
              ? SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(widget.outlined ? _kClayPurple : _kWhite)))
              : Text(widget.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: widget.outlined ? _kClaySurface : _kWhite, letterSpacing: 0.3)),
        ),
      ),
    );
  }
}

class _ClayError extends StatelessWidget {
  final String message;
  const _ClayError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kErrorBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: _kError.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _kError, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: _kError, fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
