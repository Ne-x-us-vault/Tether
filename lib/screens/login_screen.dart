import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

const _kClayPurple = Color(0xFF7C3AED);
const _kClayVivid = Color(0xFF8B5CF6);
const _kClayLight = Color(0xFFC4B5FD);
const _kClaySurface = Color(0xFFF3EEFF);
const _kClayDeep = Color(0xFF4C1D95);
const _kInputFill = Color(0xFFE9DEFA);
const _kTextDark = Color(0xFF1E1033);
const _kTextMuted = Color(0xFF8B7AA8);
const _kWhite = Color(0xFFFFFFFF);
const _kError = Color(0xFFEF4444);
const _kErrorBg = Color(0xFFFEE2E2);

TextStyle _clay(double size, {FontWeight w = FontWeight.w500, Color? c}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final Player _player;
  late final VideoController _videoController;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _supabase = SupabaseService();
  bool _loading = false;
  bool _signUp = false;
  String? _error;
  bool _obscure = true;
  bool _verifyMode = false;
  String? _verifyEmail;
  bool _eFocus = false;
  bool _pFocus = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _player = Player();
    _videoController = VideoController(_player);
    _initVideo();
  }

  Future<void> _initVideo() async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/login_clay_v3.mp4');
    if (!await f.exists()) {
      final d = await rootBundle.load('assets/login_screen/VN20260821_230619.mp4');
      await f.writeAsBytes(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));
    }
    await _player.open(Media(f.path));
    await _player.setVolume(0);
    await _player.setPlaylistMode(PlaylistMode.loop);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _player.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final e = _email.text.trim();
    final p = _password.text.trim();
    if (e.isEmpty || p.isEmpty) { setState(() => _error = 'Please fill in all fields'); return; }
    if (!e.contains('@')) { setState(() => _error = 'Please enter a valid email'); return; }
    if (p.length < 6) { setState(() => _error = 'Password must be at least 6 characters'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      if (_signUp) {
        await _supabase.signUpWithEmail(email: e, password: p);
        if (mounted) setState(() { _verifyMode = true; _verifyEmail = e; _password.clear(); });
      } else {
        await _supabase.signInWithEmail(email: e, password: p);
        final profile = await _supabase.getMyProfile();
        if (profile == null) {
          final u = _supabase.currentUser;
          if (u != null) await _supabase.upsertProfile(UserProfile(id: u.id, createdAt: DateTime.now(), updatedAt: DateTime.now()));
        }
        if (mounted) context.go('/home');
      }
    } on AuthException catch (e) { setState(() => _error = e.message); }
    catch (e) { setState(() => _error = 'An error occurred: $e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _resend() async {
    if (_verifyEmail == null) return;
    setState(() => _loading = true);
    try {
      await _supabase.signUpWithEmail(email: _verifyEmail!, password: _password.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification email sent!', style: _clay(13)), backgroundColor: _kClayPurple, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));
    } catch (e) { setState(() => _error = 'Email already registered.'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: Video(controller: _videoController, controls: NoVideoControls, fit: BoxFit.cover)),
        Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x1A1A0E3E), Color(0x881A0E3E), Color(0xF00D0620)], stops: [0.0, 0.25, 0.55, 1.0])))),
        SafeArea(child: _verifyMode ? _buildVerify() : _buildLogin()),
      ]),
    );
  }

  Widget _buildLogin() {
    return Column(children: [
      const Spacer(flex: 3),
      _ClayCard(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _ClayInput(label: 'Email', hint: 'you@example.com', icon: Icons.mail_outline_rounded, ctrl: _email, kb: TextInputType.emailAddress, focus: _eFocus, enabled: !_loading, onFocus: (f) => setState(() => _eFocus = f)),
        const SizedBox(height: 18),
        _ClayInput(label: 'Password', hint: 'Enter your password', icon: Icons.lock_outline_rounded, ctrl: _password, obscure: _obscure, focus: _pFocus, enabled: !_loading, onFocus: (f) => setState(() => _pFocus = f), suffix: GestureDetector(onTap: () => setState(() => _obscure = !_obscure), child: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: _kTextMuted, size: 20))),
        if (_error != null) ...[const SizedBox(height: 14), _ClayError(msg: _error!)],
        const SizedBox(height: 18),
        _ClayButton(label: _signUp ? 'Create Account' : 'Log In', onTap: _loading ? null : _handleAuth, loading: _loading),
      ])),
      const SizedBox(height: 20),
      GestureDetector(onTap: _loading ? null : () => setState(() { _signUp = !_signUp; _error = null; }), child: _ClayPill(child: RichText(text: TextSpan(children: [TextSpan(text: _signUp ? 'Already have an account? ' : "Don't have an account? ", style: _clay(13, c: _kTextMuted)), TextSpan(text: 'Sign Up', style: _clay(13, w: FontWeight.w700, c: _kClayPurple))])))),
      const Spacer(flex: 1),
    ]);
  }

  Widget _buildVerify() {
    return Column(children: [
      const Spacer(flex: 3),
      _ClayBubble(icon: Icons.mark_email_read_outlined),
      const SizedBox(height: 28),
      Text('Check Your Inbox', style: _clay(24, w: FontWeight.w800, c: _kWhite).copyWith(shadows: [Shadow(color: _kClayPurple.withValues(alpha: 0.6), blurRadius: 24)])),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), decoration: BoxDecoration(color: _kClayPurple.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(16)), child: Text(_verifyEmail ?? '', style: _clay(14, w: FontWeight.w600, c: _kClayLight))),
      const SizedBox(height: 10),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 48), child: Text('We sent a verification link. Click it to confirm your email.', style: _clay(13, c: _kWhite.withValues(alpha: 0.55)), textAlign: TextAlign.center)),
      const SizedBox(height: 36),
      if (_error != null) ...[Padding(padding: const EdgeInsets.symmetric(horizontal: 28), child: _ClayError(msg: _error!)), const SizedBox(height: 16)],
      _ClayButton(label: 'Resend Email', onTap: _loading ? null : _resend, loading: _loading),
      const SizedBox(height: 12),
      _ClayButton(label: 'Back to Login', onTap: _loading ? null : () => setState(() { _verifyMode = false; _verifyEmail = null; _signUp = false; _error = null; }), loading: false, outlined: true),
      const Spacer(flex: 1),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Claymorphism widgets — soft, puffy, tactile clay
// ══════════════════════════════════════════════════════════════════════════════

class _ClayCard extends StatelessWidget {
  final Widget child;
  const _ClayCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _kClaySurface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: _kClayDeep.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 16), spreadRadius: -6),
          BoxShadow(color: _kClayDeep.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(5, 7)),
          BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 10, offset: const Offset(-5, -5), spreadRadius: -3),
        ],
      ),
      child: child,
    );
  }
}

class _ClayBubble extends StatelessWidget {
  final IconData icon;
  const _ClayBubble({required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96, height: 96,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_kClayVivid, _kClayPurple]),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: _kClayDeep.withValues(alpha: 0.4), blurRadius: 32, offset: const Offset(0, 12), spreadRadius: -8),
          BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(-4, -4), spreadRadius: -2),
          BoxShadow(color: _kClayPurple.withValues(alpha: 0.5), blurRadius: 48, offset: const Offset(0, 4), spreadRadius: 12),
        ],
      ),
      child: Icon(icon, size: 42, color: _kWhite),
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
        color: _kClaySurface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(color: _kClayDeep.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.white.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(-2, -2)),
        ],
      ),
      child: child,
    );
  }
}

class _ClayInput extends StatelessWidget {
  final String label, hint;
  final IconData icon;
  final TextEditingController ctrl;
  final bool focus, enabled, obscure;
  final Function(bool) onFocus;
  final TextInputType? kb;
  final Widget? suffix;
  const _ClayInput({required this.label, required this.hint, required this.icon, required this.ctrl, required this.focus, required this.enabled, required this.onFocus, this.kb, this.obscure = false, this.suffix});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _clay(12, w: FontWeight.w700, c: focus ? _kClayPurple : _kTextMuted)),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: focus ? Colors.white : _kInputFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: focus ? _kClayPurple.withValues(alpha: 0.35) : Colors.transparent, width: 1.5),
            boxShadow: [
              BoxShadow(color: _kClayDeep.withValues(alpha: focus ? 0.14 : 0.08), blurRadius: focus ? 12 : 7, offset: const Offset(3, 4)),
              BoxShadow(color: Colors.white.withValues(alpha: 0.85), blurRadius: 5, offset: const Offset(-2, -2), spreadRadius: -1),
            ],
          ),
          child: Focus(
            onFocusChange: onFocus,
            child: TextField(
              controller: ctrl, keyboardType: kb, obscureText: obscure, enabled: enabled,
              style: _clay(15, w: FontWeight.w500, c: _kTextDark),
              decoration: InputDecoration(
                hintText: hint, hintStyle: _clay(14, c: _kTextMuted.withValues(alpha: 0.45)),
                border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                prefixIcon: Padding(padding: const EdgeInsets.only(left: 16, right: 10), child: Icon(icon, color: focus ? _kClayPurple : _kTextMuted, size: 20)),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.only(right: 16), child: suffix) : null,
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
  final VoidCallback? onTap;
  final bool loading, outlined;
  const _ClayButton({required this.label, required this.onTap, this.loading = false, this.outlined = false});
  @override
  State<_ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<_ClayButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final off = widget.onTap == null || widget.loading;
    return GestureDetector(
      onTapDown: off ? null : (_) => setState(() => _down = true),
      onTapUp: off ? null : (_) { setState(() => _down = false); widget.onTap?.call(); },
      onTapCancel: off ? null : () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(0, _down ? 2.5 : 0, 0),
        height: 56,
        decoration: widget.outlined
            ? BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(22), border: Border.all(color: _kClaySurface.withValues(alpha: 0.4), width: 2), boxShadow: [BoxShadow(color: _kClayDeep.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))])
            : BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_kClayVivid, _kClayPurple]),
                borderRadius: BorderRadius.circular(22),
                boxShadow: off
                    ? [BoxShadow(color: _kClayDeep.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))]
                    : [
                        BoxShadow(color: _kClayDeep.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 8), spreadRadius: -3),
                        BoxShadow(color: _kClayPurple.withValues(alpha: 0.35), blurRadius: 36, offset: const Offset(0, 4), spreadRadius: 8),
                        BoxShadow(color: Colors.white.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(-2, -2)),
                      ],
              ),
        child: Center(
          child: widget.loading
              ? SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(widget.outlined ? _kClayPurple : _kWhite)))
              : Text(widget.label, style: _clay(15, w: FontWeight.w700, c: widget.outlined ? _kClaySurface : _kWhite)),
        ),
      ),
    );
  }
}

class _ClayError extends StatelessWidget {
  final String msg;
  const _ClayError({required this.msg});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _kErrorBg, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: _kError.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: _kError, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: _clay(13, w: FontWeight.w500, c: _kError))),
      ]),
    );
  }
}
