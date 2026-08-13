import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';

const _kBgDark = Color(0xFF09090B);
const _kBgLight = Color(0xFFF4F4F5);
const _kAccentPurple = Color(0xFF8B5CF6);
const _kAccentPink = Color(0xFFF43F5E);
const _kTextPrimary = Colors.white;
const _kTextSecondary = Color(0xFFA1A1AA);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _sb = SupabaseService();
  final String _appVersion = '1.0.2 (Build 42)';

  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _loadSharedSettings();
  }

  Future<void> _loadSharedSettings() async {
    final profile = await _sb.getMyProfile();
    if (profile != null) {
      final prefs = profile.preferences;
      setState(() {
        _isDarkMode = prefs['dark_mode'] ?? true;
      });
    }
  }

  Future<void> _updateSharedSetting(String key, dynamic value) async {
    try {
      final profile = await _sb.getMyProfile();
      if (profile == null) return;

      final updatedPrefs = Map<String, dynamic>.from(profile.preferences);
      updatedPrefs[key] = value;

      await _sb.client
          .from('profiles')
          .update({
            'preferences': updatedPrefs,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _sb.currentUserId!);

      setState(() {
        if (key == 'dark_mode') _isDarkMode = value;
      });

      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('[Settings] Error updating shared setting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? _kBgDark : _kBgLight,
      body: Stack(
        children: [
          Positioned(
            top: -150,
            left: -50,
            child: _GlowBlob(
              400,
              _kAccentPurple.withValues(alpha: _isDarkMode ? 0.08 : 0.15),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: _GlowBlob(
              350,
              _kAccentPink.withValues(alpha: _isDarkMode ? 0.05 : 0.1),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildProfileCard(),
                      const SizedBox(height: 24),
                      _buildSection('APPEARANCE (SHARED)', [
                        _SettingsSwitchRow(
                          icon: Icons.dark_mode_outlined,
                          title: 'Dark Mode',
                          subtitle: _isDarkMode
                              ? 'Deep Obsidian'
                              : 'Clean Frost',
                          value: _isDarkMode,
                          onChanged: (v) =>
                              _updateSharedSetting('dark_mode', v),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _buildSection('ACCOUNT & CONNECTIVITY', [
                        _SettingsRow(
                          icon: Icons.favorite_border_rounded,
                          title: 'Edit Partner Nickname',
                          subtitle: 'Set partner nickname & avatar',
                          onTap: () async {
                            await context.push('/edit_profile');
                            if (mounted) setState(() {});
                          },
                        ),
                        _SettingsRow(
                          icon: Icons.notifications_none_rounded,
                          title: 'Notifications',
                          subtitle: 'View recent shared alerts and updates',
                          onTap: () => context.push('/notifications'),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _buildSection('SUPPORT', [
                        _SettingsRow(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          onTap: _showPrivacyPolicy,
                        ),
                        _SettingsRow(
                          icon: Icons.mail_outline_rounded,
                          title: 'Contact Support',
                          onTap: _contactSupport,
                        ),
                        _SettingsRow(
                          icon: Icons.info_outline_rounded,
                          title: 'About Lovit',
                          subtitle: 'Version $_appVersion',
                          onTap: _showAbout,
                        ),
                      ]),
                      const SizedBox(height: 32),
                      _buildLogoutButton(),
                      const SizedBox(height: 48),
                      Center(
                        child: Text(
                          'MADE WITH ❤️ BY JASWA',
                          style: TextStyle(
                            color: (_isDarkMode ? Colors.white : Colors.black)
                                .withValues(alpha: 0.1),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textCol = _isDarkMode ? _kTextPrimary : Colors.black87;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (_isDarkMode ? Colors.white : Colors.black).withValues(alpha: 
                  0.04,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: (_isDarkMode ? Colors.white : Colors.black)
                      .withValues(alpha: 0.08),
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: textCol,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Settings',
            style: TextStyle(
              color: textCol,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final textCol = _isDarkMode ? _kTextPrimary : Colors.black87;
    return FutureBuilder(
      future: _sb.getMyProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: (_isDarkMode ? Colors.white : Colors.black).withValues(alpha: 
              0.03,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: (_isDarkMode ? Colors.white : Colors.black).withValues(alpha: 
                0.08,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_kAccentPurple, _kAccentPink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isDarkMode
                          ? const Color(0xFF131318)
                          : Colors.white,
                    ),
                    child: ClipOval(
                      child:
                          profile?.avatarUrl != null &&
                              profile!.avatarUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: profile.avatarUrl!,
                              fit: BoxFit.cover,
                            )
                          : Icon(
                              Icons.person_rounded,
                              color: _isDarkMode
                                  ? Colors.white
                                  : _kAccentPurple,
                              size: 28,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You',
                      style: TextStyle(
                        color: textCol,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (_isDarkMode ? Colors.white : Colors.black)
                      .withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: _isDarkMode ? Colors.white24 : Colors.black12,
                  size: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    final titleCol = _isDarkMode ? _kTextSecondary : Colors.black54;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              color: titleCol.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: (_isDarkMode ? Colors.white : Colors.black).withValues(alpha: 
              0.02,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: (_isDarkMode ? Colors.white : Colors.black).withValues(alpha: 
                0.06,
              ),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    final textCol = _isDarkMode ? _kTextPrimary : Colors.black87;
    const pleasantRed = Color(0xFFFF8FA2);
    return InkWell(
      onTap: _handleLogout,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: pleasantRed.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: pleasantRed.withValues(alpha: 0.25), width: 1.0),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: pleasantRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: pleasantRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log Out',
                    style: TextStyle(
                      color: textCol,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sign out of your account',
                    style: TextStyle(
                      color: pleasantRed.withValues(alpha: 0.65),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: pleasantRed.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1525), Color(0xFF0D0D16)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kAccentPurple.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🔒', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privacy Policy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Effective: May 2025 · Lovit v1.0',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Container(
                height: 0.5,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                color: Colors.white.withValues(alpha: 0.08),
              ),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    _policySection(
                      '💜 Our Promise to You',
                      'Lovit is a private space built exclusively for you and your partner. We take your privacy seriously — your data belongs to you, not us.',
                    ),
                    _policySection(
                      '📦 What We Collect',
                      'We collect only what is necessary:\n• Your name and profile photo\n• Messages and media you send\n• App preferences (dark mode, etc.)\n• Device info for notifications',
                    ),
                    _policySection(
                      '🔐 How We Protect It',
                      'All data is encrypted in transit using TLS 1.3. Message text is encrypted end-to-end on your devices (AES-256-GCM) before it is sent — the server only ever holds ciphertext. Your other data is stored securely on Supabase servers with row-level security (RLS), so only you and your partner can access it.',
                    ),
                    _policySection(
                      '🚫 What We Never Do',
                      'We never:\n• Sell your data to third parties\n• Use your messages for advertising\n• Share your information without consent\n• Read your private conversations',
                    ),
                    _policySection(
                      '📸 Media & Files',
                      'Photos, videos, and documents you share are stored in a private Supabase bucket accessible only to your pairing. We do not analyse or scan your media.',
                    ),
                    _policySection(
                      '🗑️ Your Right to Delete',
                      'You can delete your messages, media, and account at any time. On deletion, all associated data is permanently removed from our servers within 30 days.',
                    ),
                    _policySection(
                      '🔔 Notifications',
                      'Push notification tokens are stored solely to deliver your messages. They are never used for marketing.',
                    ),
                    _policySection(
                      '📬 Contact',
                      'Questions about privacy? Honestly, just ask Jas 😉 — he built this whole thing for you.',
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '© 2025 Lovit · Made with 💜 by Jaswa',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Close button
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  24 + MediaQuery.of(ctx).padding.bottom,
                ),
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kAccentPurple, Color(0xFFF43F5E)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: _kAccentPurple.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Got it, we\'re safe 💜',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _policySection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  void _contactSupport() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1C1529), Color(0xFF0D0D16)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: _kAccentPurple.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _kAccentPurple.withValues(alpha: 0.25),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing heart icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kAccentPurple.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Center(
                  child: Text('😉', style: TextStyle(fontSize: 38)),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Need Help?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                'Ask your hubby Jas 😉\nfor any doubts!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),

              // Close button
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kAccentPurple, Color(0xFFF43F5E)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _kAccentPurple.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Got it 💜',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Lovit',
      applicationVersion: _appVersion,
      applicationIcon: const Icon(
        Icons.favorite_rounded,
        color: _kAccentPink,
        size: 40,
      ),
      applicationLegalese: '© 2026 Jaswa. All rights reserved.',
    );
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBgDark,
        title: const Text('Log Out?', style: TextStyle(color: _kTextPrimary)),
        content: const Text(
          'Are you sure you want to log out? You\'ll need to log in again to access your account.',
          style: TextStyle(color: _kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _kAccentPurple),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _sb.signOut();
                if (mounted) {
                  context.go('/');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error logging out: $e'),
                      backgroundColor: _kAccentPink,
                    ),
                  );
                }
              }
            },
            child: const Text('Log Out', style: TextStyle(color: _kAccentPink)),
          ),
        ],
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark ||
        value; // Simplified check
    final textCol = isDark ? _kTextPrimary : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _kAccentPurple, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textCol,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: (isDark ? _kTextSecondary : Colors.black54)
                          .withValues(alpha: 0.4),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _kAccentPurple,
            activeTrackColor: _kAccentPurple.withValues(alpha: 0.2),
            inactiveTrackColor: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: 0.05),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    // ignore: unused_element_parameter
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textCol = Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _kAccentPurple, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textCol,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.1),
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob(this.size, this.color);
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}
