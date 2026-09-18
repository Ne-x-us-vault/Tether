import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../theme/clay.dart';

// ══════════════════════════════════════════════════════════════════════════════
// LOGIN / SIGN UP — pastel clay
//
// The front door of Lovit: a soft pastel wash, a clay emblem of two people
// leaning together, and a pressed-clay form. One orchestrated entrance, quiet
// ambient motion, and honest error states.
// ══════════════════════════════════════════════════════════════════════════════

// Demo account seeded for reviewers (see README → Admin / demo access).
const String _kDemoEmail = 'admin@lovit.app';
const String _kDemoPassword = 'Lovit@Admin2026';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _supabase = SupabaseService();

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool _loading = false;
  bool _signUp = false;
  bool _obscure = true;
  bool _verifyMode = false;
  bool _eFocus = false;
  bool _pFocus = false;
  String? _verifyEmail;
  String? _error;
  String? _success;

  static const _darkSystemUi = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: ClayPalette.blush,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static const _appSystemUi = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF09080E),
    systemNavigationBarIconBrightness: Brightness.light,
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(_darkSystemUi);
    _intro.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _intro.value = 1;
    }
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(_appSystemUi);
    _intro.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _handleAuth() async {
    final email = _email.text.trim();
    final password = _password.text;
    FocusScope.of(context).unfocus();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Add your email and password to continue.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'That email does not look right.');
      return;
    }
    if (_signUp && password.length < 6) {
      setState(() => _error = 'Use at least 6 characters for your password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      if (_signUp) {
        final response =
            await _supabase.signUpWithEmail(email: email, password: password);
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        if (response.session != null) {
          // Confirmation is disabled on this project — the account is live.
          await _ensureProfile();
          if (mounted) context.go('/home');
        } else {
          setState(() {
            _verifyMode = true;
            _verifyEmail = email;
            _password.clear();
          });
        }
      } else {
        await _supabase.signInWithEmail(email: email, password: password);
        await _ensureProfile();
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        context.go('/home');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthMessage(e.message));
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not reach Lovit. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ensureProfile() async {
    final profile = await _supabase.getMyProfile();
    if (profile != null) return;
    final user = _supabase.currentUser;
    if (user == null) return;
    await _supabase.upsertProfile(
      UserProfile(
        id: user.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _resend() async {
    final email = _verifyEmail;
    if (email == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      await _supabase.resendVerificationEmail(email);
      if (mounted) {
        setState(() => _success = 'Sent again. Check your inbox and spam folder.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthMessage(e.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send the email. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ClayPalette.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          'Reset your password',
          style: ClayType.display(21, weight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We will email you a secure link to choose a new password.',
              style: ClayType.body(14, color: ClayPalette.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 16),
            ClayWell(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                style: ClayType.body(15, weight: FontWeight.w600),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'you@example.com',
                  hintStyle: ClayType.body(14, color: ClayPalette.inkFaint),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: ClayType.body(14, weight: FontWeight.w700, color: ClayPalette.inkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Send link',
                style: ClayType.body(14, weight: FontWeight.w800, color: ClayPalette.lilacDeep)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty) return;
    if (!email.contains('@')) {
      setState(() => _error = 'That email does not look right.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      await _supabase.sendPasswordResetEmail(email);
      if (mounted) setState(() => _success = 'Reset link sent to $email.');
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthMessage(e.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send the email. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthMessage(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('invalid login')) return 'That email or password is not right.';
    if (m.contains('already registered')) return 'That email already has an account. Log in instead.';
    if (m.contains('email not confirmed')) return 'Confirm your email first — check your inbox.';
    if (m.contains('rate limit')) return 'Too many attempts. Take a breath and try again shortly.';
    if (m.contains('password')) return 'That password is too weak. Use 8+ characters with letters and numbers.';
    return raw;
  }

  void _setMode(bool signUp) {
    HapticFeedback.selectionClick();
    setState(() {
      _signUp = signUp;
      _error = null;
      _success = null;
    });
  }

  void _backToLogin() {
    setState(() {
      _verifyMode = false;
      _verifyEmail = null;
      _signUp = false;
      _error = null;
      _success = null;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: ClayPalette.blush,
      resizeToAvoidBottomInset: false,
      body: PastelClayBackground(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: _darkSystemUi,
          child: SafeArea(
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 26,
                      right: 26,
                      bottom: bottomInset + 18,
                    ),
                    child: _verifyMode ? _buildVerify() : _buildAuth(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reveal(double begin, Widget child) {
    final end = (begin + 0.55).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: _intro,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.10),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  Widget _buildAuth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _reveal(
          0.00,
          Column(
            children: [
              const ClayWordmark(fontSize: 42),
              const SizedBox(height: 4),
              Text(
                'a soft place for two',
                style: ClayType.body(
                  14,
                  weight: FontWeight.w600,
                  color: ClayPalette.inkSoft,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 3),
        _reveal(0.10, const Center(child: ClayHeroEmblem(size: 138))),
        const SizedBox(height: 26),
        _reveal(
          0.22,
          ClayPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _signUp ? 'Begin your story' : 'Welcome back',
                  style: ClayType.display(27, weight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  _signUp
                      ? 'Create an account for you and your partner.'
                      : 'Sign in to your private shared space.',
                  style: ClayType.body(14.5, color: ClayPalette.inkSoft, height: 1.35),
                ),
                const SizedBox(height: 22),
                _ClayField(
                  label: 'Email',
                  hint: 'you@example.com',
                  icon: Icons.mail_outline_rounded,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_loading,
                  focused: _eFocus,
                  autofillHints: const [AutofillHints.email],
                  onFocus: (f) => setState(() => _eFocus = f),
                ),
                const SizedBox(height: 16),
                _ClayField(
                  label: 'Password',
                  hint: _signUp ? 'Create a password' : 'Your password',
                  icon: Icons.lock_outline_rounded,
                  controller: _password,
                  obscure: _obscure,
                  enabled: !_loading,
                  focused: _pFocus,
                  textInputAction: TextInputAction.done,
                  autofillHints: [
                    _signUp ? AutofillHints.newPassword : AutofillHints.password,
                  ],
                  onFocus: (f) => setState(() => _pFocus = f),
                  onSubmitted: (_) {
                    if (!_loading) _handleAuth();
                  },
                  trailing: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: ClayPalette.inkFaint,
                      size: 20,
                    ),
                  ),
                ),
                if (!_signUp)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading ? null : _forgotPassword,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Forgot password?',
                        style: ClayType.body(13.5,
                            weight: FontWeight.w700, color: ClayPalette.lilacDeep),
                      ),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  ClayBanner(message: _error!),
                ],
                if (_success != null) ...[
                  const SizedBox(height: 14),
                  ClayBanner(
                    message: _success!,
                    icon: Icons.check_circle_outline_rounded,
                    foreground: ClayPalette.success,
                    background: ClayPalette.successBg,
                  ),
                ],
                const SizedBox(height: 20),
                ClayButton(
                  label: _signUp ? 'Create account' : 'Log in',
                  loading: _loading,
                  onTap: _loading ? null : _handleAuth,
                  icon: _loading ? null : Icons.favorite_rounded,
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                                _email.text = _kDemoEmail;
                                _password.text = _kDemoPassword;
                                _signUp = false;
                                _error = null;
                              }),
                      child: Text(
                        'Fill demo admin',
                        style: ClayType.body(12.5,
                            weight: FontWeight.w700, color: ClayPalette.inkFaint),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _reveal(
          0.34,
          Center(
            child: GestureDetector(
              onTap: _loading ? null : () => _setMode(!_signUp),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _signUp
                            ? 'Already have an account?  '
                            : 'New to Lovit?  ',
                        style: ClayType.body(14,
                            weight: FontWeight.w600, color: ClayPalette.inkSoft),
                      ),
                      TextSpan(
                        text: _signUp ? 'Log in' : 'Create account',
                        style: ClayType.body(14,
                            weight: FontWeight.w800, color: ClayPalette.lilacDeep),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Spacer(flex: 1),
        _reveal(
          0.44,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 13, color: ClayPalette.inkFaint),
              const SizedBox(width: 6),
              Text(
                'Private by design · Messages are end-to-end encrypted',
                style: ClayType.body(11.5,
                    weight: FontWeight.w600, color: ClayPalette.inkFaint),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerify() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 2),
        _reveal(
          0.00,
          Column(
            children: [
              _ClayIconTile(
                icon: Icons.mark_email_read_outlined,
                colors: const [Color(0xFFCFC2F5), ClayPalette.lilac],
              ),
              const SizedBox(height: 26),
              Text(
                'Check your inbox',
                textAlign: TextAlign.center,
                style: ClayType.display(27, weight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a confirmation link to',
                textAlign: TextAlign.center,
                style: ClayType.body(14.5, color: ClayPalette.inkSoft),
              ),
              const SizedBox(height: 12),
              Center(
                child: ClayChip(
                  label: _verifyEmail ?? '',
                  icon: Icons.alternate_email_rounded,
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  'Open the link to confirm your email, then come back and log in.',
                  textAlign: TextAlign.center,
                  style: ClayType.body(13.5, color: ClayPalette.inkSoft, height: 1.4),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 18),
                ClayBanner(message: _error!),
              ],
              if (_success != null) ...[
                const SizedBox(height: 18),
                ClayBanner(
                  message: _success!,
                  icon: Icons.check_circle_outline_rounded,
                  foreground: ClayPalette.success,
                  background: ClayPalette.successBg,
                ),
              ],
              const SizedBox(height: 24),
              ClayButton(
                label: 'Resend email',
                loading: _loading,
                onTap: _loading ? null : _resend,
                icon: _loading ? null : Icons.refresh_rounded,
              ),
              const SizedBox(height: 12),
              ClayGhostButton(
                label: 'Back to log in',
                icon: Icons.arrow_back_rounded,
                onTap: _loading ? null : _backToLogin,
              ),
            ],
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Local field + tile widgets
// ══════════════════════════════════════════════════════════════════════════════

class _ClayField extends StatelessWidget {
  const _ClayField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.focused,
    required this.enabled,
    required this.onFocus,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.trailing,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool focused;
  final bool enabled;
  final ValueChanged<bool> onFocus;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final Widget? trailing;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            label,
            style: ClayType.body(
              12.5,
              weight: FontWeight.w700,
              color: focused ? ClayPalette.lilacDeep : ClayPalette.inkSoft,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Focus(
          onFocusChange: onFocus,
          child: ClayWell(
            focused: focused,
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: focused ? ClayPalette.lilacDeep : ClayPalette.inkFaint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    obscureText: obscure,
                    enabled: enabled,
                    keyboardType: keyboardType,
                    textInputAction: textInputAction,
                    autofillHints: autofillHints,
                    onSubmitted: onSubmitted,
                    style: ClayType.body(15.5, weight: FontWeight.w600),
                    cursorColor: ClayPalette.lilacDeep,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      hintText: hint,
                      hintStyle: ClayType.body(14.5,
                          color: ClayPalette.inkFaint, weight: FontWeight.w500),
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ClayIconTile extends StatelessWidget {
  const _ClayIconTile({required this.icon, required this.colors});

  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: ClayPalette.paper,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: ClayPalette.shadowDeep.withValues(alpha: 0.30),
            blurRadius: 30,
            offset: const Offset(0, 14),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            blurRadius: 10,
            offset: const Offset(-5, -5),
            spreadRadius: -3,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
