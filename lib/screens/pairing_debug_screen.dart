import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/glass.dart';

class PairingDebugScreen extends StatefulWidget {
  const PairingDebugScreen({super.key});

  @override
  State<PairingDebugScreen> createState() => _PairingDebugScreenState();
}

class _PairingDebugScreenState extends State<PairingDebugScreen> {
  final SupabaseService _sb = SupabaseService();
  String _debugLog = 'Starting debug session...\n';
  bool _isLoading = false;
  final TextEditingController _joinCodeCtrl = TextEditingController();

  @override
  void dispose() {
    _joinCodeCtrl.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      _debugLog += '${DateTime.now().toString().split('.')[0]} > $message\n';
    });
    debugPrint(message);
  }

  Future<void> _testConnection() async {
    setState(() => _isLoading = true);
    _addLog('🔌 Testing Supabase connection...');

    try {
      final user = _sb.currentUser;
      if (user == null) {
        _addLog('❌ No user found. Sign in with an account first.');
        setState(() => _isLoading = false);
        return;
      } else {
        _addLog('✅ User already signed in: ${user.id}');
      }

      // Test database query
      await _sb.client
          .from('pairings')
          .select()
          .limit(1);
      _addLog('✅ Database query successful. Pairings table accessible.');
    } catch (e) {
      _addLog('❌ Connection error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testCreatePairing() async {
    setState(() => _isLoading = true);
    _addLog('🔄 Creating test pairing...');

    try {
      final pairing = await _sb.createPairing();
      _addLog('✅ Pairing created successfully!');
      _addLog('   ID: ${pairing.id}');
      _addLog('   Code: ${pairing.pairingCode}');
      _addLog('   Status: ${pairing.status}');
      _addLog('   User1 ID: ${pairing.user1Id}');
      _addLog('   Expires at: ${pairing.expiresAt}');
    } catch (e) {
      _addLog('❌ Failed to create pairing: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testJoinPairing() async {
    // Joining your own pairing is blocked server-side (join_pairing RPC raises
    // "You cannot join your own pairing"), so this test needs a code created
    // on another device. Prompt for it instead of self-joining.
    final code = await _promptForCode();
    if (code == null) return;
    setState(() => _isLoading = true);
    _addLog('🔄 Joining pairing with code: $code');

    try {
      final joined = await _sb.joinPairing(code);
      _addLog('✅ Successfully joined pairing!');
      _addLog('   Joined Pairing ID: ${joined.id}');
      _addLog('   User1 ID: ${joined.user1Id}');
      _addLog('   User2 ID: ${joined.user2Id}');
      _addLog('   Status: ${joined.status}');
    } catch (e) {
      _addLog('❌ Failed to join pairing: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<String?> _promptForCode() async {
    _joinCodeCtrl.clear();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Pairing'),
        content: TextField(
          controller: _joinCodeCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Pairing code from partner device',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _joinCodeCtrl.text.trim().toUpperCase()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (entered == null || entered.isEmpty) {
      _addLog('⚠️  Join cancelled or empty code');
      return null;
    }
    return entered;
  }

  Future<void> _testGetActivePairing() async {
    setState(() => _isLoading = true);
    _addLog('🔄 Fetching active pairing...');

    try {
      final pairing = await _sb.getActivePairing();
      if (pairing == null) {
        _addLog('⚠️  No active pairing found for current user');
      } else {
        _addLog('✅ Active pairing found:');
        _addLog('   ID: ${pairing.id}');
        _addLog('   Code: ${pairing.pairingCode}');
        _addLog('   User1: ${pairing.user1Id}');
        _addLog('   User2: ${pairing.user2Id}');
        _addLog('   Status: ${pairing.status}');
      }
    } catch (e) {
      _addLog('❌ Error fetching active pairing: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testWatchPairing() async {
    setState(() => _isLoading = true);
    _addLog('🔄 Creating pairing and watching for changes...');

    try {
      final pairing = await _sb.createPairing();
      _addLog('✅ Created pairing with code: ${pairing.pairingCode}');
      _addLog('   Now watching for real-time updates...');

      // Watch for updates
      final subscription = _sb.watchPairingCode(pairing.pairingCode).listen((updated) {
        if (updated != null) {
          _addLog('🔄 Real-time update received:');
          _addLog('   Status: ${updated.status}');
          _addLog('   User1: ${updated.user1Id}');
          _addLog('   User2: ${updated.user2Id}');
        }
      });

      // Keep listening for 5 seconds
      await Future.delayed(const Duration(seconds: 5));
      subscription.cancel();
      _addLog('✅ Watch test completed');
    } catch (e) {
      _addLog('❌ Error in watch test: $e');
    }

    setState(() => _isLoading = false);
  }

  void _clearLog() {
    setState(() => _debugLog = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Pairing Backend Debug'),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: const Color(0x7A111712)),
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: LovitBackground(
              blurSigma: 24,
              darkOverlayOpacity: 0.56,
              vignetteOpacity: 0.28,
            ),
          ),
          Column(
        children: [
          // Status Section
          Container(
            color: const Color(0xFF1A1530),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current User: ${_sb.currentUserId ?? "Not signed in"}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Supabase Connected',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _TestButton(
                  label: 'Test Connection',
                  onPressed: _isLoading ? null : _testConnection,
                ),
                _TestButton(
                  label: 'Create Pairing',
                  onPressed: _isLoading ? null : _testCreatePairing,
                ),
                _TestButton(
                  label: 'Join Pairing',
                  onPressed: _isLoading ? null : _testJoinPairing,
                ),
                _TestButton(
                  label: 'Get Active',
                  onPressed: _isLoading ? null : _testGetActivePairing,
                ),
                _TestButton(
                  label: 'Watch Updates',
                  onPressed: _isLoading ? null : _testWatchPairing,
                ),
                _TestButton(
                  label: 'Clear Log',
                  onPressed: _isLoading ? null : _clearLog,
                  color: Colors.red,
                ),
              ],
            ),
          ),
          // Debug Log
          Expanded(
            child: Container(
              color: const Color(0x77111712),
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                reverse: true,
                child: SelectableText(
                  _debugLog,
                  style: const TextStyle(
                    color: Color(0xFFB39DFF),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TEST BUTTON WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class _TestButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const _TestButton({
    required this.label,
    this.onPressed,
    this.color = const Color(0xFFC9BFFF),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          foregroundColor: const Color(0xFF09080E),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
