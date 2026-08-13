// pairing_screen.dart — Lovit App (Original beautiful UI + Supabase backend)
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../widgets/glass.dart';

// ----- Constants (accessible in all helper widgets) -----
const Color _kBg = Color(0xFF131318);
const Color _kPurple = Color(0xFFC9BFFF);
const Color _kText = Color(0xFFE4E1E9);
const Color _kTextSub = Color(0xFFC9C4D1);
const Color _kBtnTxt = Color(0xFF312762);
// --------------------------------------------------------

enum _PairingState {
  selection,
  generating,
  scanning,
  manualEntry,
  connecting,
  paired,
}

class PairingScreen extends StatefulWidget {
  final VoidCallback onPaired;
  final VoidCallback? onSkip;
  const PairingScreen({super.key, required this.onPaired, this.onSkip});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen>
    with TickerProviderStateMixin {
  _PairingState _state = _PairingState.selection;

  // ═══ New backend fields ═══
  final SupabaseService _sb = SupabaseService();
  Pairing? _currentPairing; // active pairing object
  StreamSubscription? _pairingSub; // listener for partner joining
  Timer? _pairingPollTimer; // fallback polling timer
  bool _subscriptionActive = false; // track subscription health

  // ═══ Animations ═══
  late AnimationController _glowCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _orbitCtrl;
  late AnimationController _scanLineCtrl;
  late AnimationController _successCtrl;
  late AnimationController _awaitCtrl;

  late Animation<double> _glowAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _successAnim;

  // ═══ Scanner ═══
  MobileScannerController? _scanner;
  bool _scannedOnce = false;
  final bool _torch = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _initProfileCheck();
  }

  /// Make sure the user's profile exists in the profiles table
  Future<void> _initProfileCheck() async {
    final user = _sb.currentUser;
    if (user == null) return;
    final exists = await _sb.getMyProfile();
    if (exists == null) {
      // Create a minimal profile on first use
      await _sb.upsertProfile(
        UserProfile(
          id: user.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  void _initControllers() {
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _awaitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
    _pulseAnim = Tween<double>(
      begin: 0.87,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _successAnim = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _pulseCtrl.dispose();
    _orbitCtrl.dispose();
    _scanLineCtrl.dispose();
    _successCtrl.dispose();
    _awaitCtrl.dispose();
    _scanner?.dispose();
    _pairingSub?.cancel();
    _pairingPollTimer?.cancel();
    super.dispose();
  }

  String? _errorMessage;

  // ═══════════════════════════════════════════════════════════════
  // BACKEND ACTIONS (REPLACED)
  // ═══════════════════════════════════════════════════════════════

  /// Generate QR code: create a pairing in DB and listen for partner
  Future<void> _onGenerateQR() async {
    final uid = _sb.currentUserId;
    if (uid == null) {
      setState(() {
        _errorMessage = 'Authentication error. Please sign in again.';
        _state = _PairingState.selection;
      });
      return;
    }

    setState(() {
      _state = _PairingState.generating;
      _errorMessage = null;
    });

    try {
      debugPrint('[Lovit/Pairing] Cleaning up existing pending pairings...');
      // 1. Delete any existing pending pairing for this user
      await _sb.client
          .from('pairings')
          .delete()
          .eq('user1_id', uid)
          .eq('status', 'pending');

      debugPrint('[Lovit/Pairing] Creating new pairing...');
      // 2. Create new pairing
      final pairing = await _sb.createPairing();

      if (mounted) {
        setState(() {
          _currentPairing = pairing;
        });
        debugPrint('[Lovit/Pairing] Created pairing: ${pairing.pairingCode}');

        // 3. Setup realtime listener for partner join
        _setupPairingSubscription(pairing.pairingCode);

        // 4. Setup polling fallback (in case realtime fails)
        _setupPairingPolling(pairing.id);
      }
    } catch (e) {
      debugPrint('[Lovit/Pairing] Generation error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Generation error: ${e.toString().split('\n').first}';
          _state = _PairingState.selection;
        });
      }
    }
  }

  /// Setup realtime subscription to watch for partner joining
  void _setupPairingSubscription(String pairingCode) {
    _pairingSub?.cancel();
    _subscriptionActive = false;

    debugPrint(
      '[Lovit/Pairing] Setting up subscription for code: $pairingCode',
    );

    _pairingSub = _sb
        .watchPairingCode(pairingCode)
        .listen(
          (updated) {
            debugPrint('[Lovit/Pairing] Subscription update: $updated');
            _subscriptionActive = true;

            if (updated == null) {
              debugPrint('[Lovit/Pairing] Update is null');
              return;
            }

            if (updated.status == 'active' && updated.user2Id != null) {
              debugPrint('[Lovit/Pairing] Partner joined! Finalizing pairing.');
              _finalizePairing(pairing: updated);
            }
          },
          onError: (error) {
            debugPrint('[Lovit/Pairing] Subscription error: $error');
            _subscriptionActive = false;
            // Polling fallback will handle reconnection
          },
          onDone: () {
            debugPrint('[Lovit/Pairing] Subscription closed');
            _subscriptionActive = false;
          },
        );
  }

  /// Setup polling as fallback in case realtime subscription fails
  void _setupPairingPolling(String pairingId) {
    _pairingPollTimer?.cancel();

    // Poll every 2 seconds if subscription is not active
    _pairingPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_subscriptionActive &&
          _state == _PairingState.generating &&
          mounted) {
        try {
          final updated = await _sb.getPairing(pairingId);
          if (updated != null &&
              updated.status == 'active' &&
              updated.user2Id != null) {
            debugPrint('[Lovit/Pairing] Polling detected partner join!');
            _finalizePairing(pairing: updated);
          }
        } catch (e) {
          debugPrint('[Lovit/Pairing] Polling error: $e');
        }
      }
    });
  }

  /// Data for the QR image (6‑char code)
  /// The scanner will parse this URI
  String get _qrData {
    final code = _currentPairing?.pairingCode ?? '------';
    return 'lovlet://pair?code=$code';
  }

  /// Open camera scanner
  Future<void> _onOpenScanner() async {
    final status = await Permission.camera.status;
    if (!status.isGranted && !await Permission.camera.request().isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission required')),
      );
      return;
    }
    _scannedOnce = false;
    _scanner?.dispose();
    _scanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: _torch,
    );
    setState(() => _state = _PairingState.scanning);
  }

  void _openManualEntry() {
    setState(() => _state = _PairingState.manualEntry);
  }

  /// Called when a barcode is detected
  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_scannedOnce) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || !raw.startsWith('lovlet://pair?')) return;

    _scannedOnce = true;
    await _scanner?.stop();
    setState(() => _state = _PairingState.connecting);

    final uri = Uri.parse(raw);
    final code = uri.queryParameters['code'];
    if (code == null || code.length != 6) {
      _showError('Invalid QR code');
      return;
    }

    try {
      final joined = await _sb.joinPairing(code);
      _finalizePairing(pairing: joined);
    } catch (e) {
      _showError('Invalid or expired pairing code');
    }
  }

  /// Manual code entry submission
  Future<void> _submitManualCode(String code) async {
    setState(() => _state = _PairingState.connecting);
    try {
      final joined = await _sb.joinPairing(code);
      _finalizePairing(pairing: joined);
    } catch (e) {
      setState(() => _state = _PairingState.manualEntry);
      _showError('Invalid code');
    }
  }

  /// Finalize pairing – store in SharedPreferences, play success animation
  Future<void> _finalizePairing({required Pairing pairing}) async {
    _pairingSub?.cancel();
    _currentPairing = pairing;

    // Save pairing ID for later use in other screens
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_pairing_id', pairing.id);

    if (!mounted) return;
    setState(() => _state = _PairingState.paired);
    _successCtrl.forward();
    HapticFeedback.heavyImpact();

    // After celebration, navigate to home
    Future.delayed(const Duration(milliseconds: 1800), () {
      widget.onPaired();
    });
  }

  void _showError(String message) {
    setState(() => _state = _PairingState.selection);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goBack() {
    _scanner?.dispose();
    _pairingSub?.cancel();
    _pairingPollTimer?.cancel();
    _successCtrl.reset();
    _scannedOnce = false;
    _currentPairing = null;
    _subscriptionActive = false;
    setState(() {
      _state = _PairingState.selection;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // UI REMAINS EXACTLY THE SAME (only backend calls changed)
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(
            child: LovitBackground(
              blurSigma: 24,
              darkOverlayOpacity: 0.56,
              vignetteOpacity: 0.28,
            ),
          ),
          _Background(glowAnim: _glowAnim),
          SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(parent: anim, curve: Curves.easeOut),
                      ),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_state),
                child: _buildCurrentState(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentState() {
    switch (_state) {
      case _PairingState.selection:
        return _buildSelection();
      case _PairingState.generating:
        return _buildGenerating();
      case _PairingState.scanning:
        return _buildScanning();
      case _PairingState.manualEntry:
        return _buildManualEntry();
      case _PairingState.connecting:
        return _buildConnecting();
      case _PairingState.paired:
        return _buildPaired();
    }
  }

  // ------------------- UI Builders (original glass design) -------------------
  Widget _buildSelection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _TopBar(onSkip: widget.onSkip),
          const SizedBox(height: 52),
          const Text(
            'Scan To Pair',
            style: TextStyle(
              color: _kText,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.75,
              height: 1.20,
            ),
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: 0.80,
            child: const Text(
              'Connect with your partner to begin\nyour journey together.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kTextSub, fontSize: 16, height: 1.63),
            ),
          ),
          const SizedBox(height: 36),
          _GlassCard(
            glowAnim: _glowAnim,
            child: Column(
              children: [
                _PairButton(
                  icon: Icons.qr_code_rounded,
                  label: 'Generate QR Code',
                  glowAnim: _glowAnim,
                  onTap: _onGenerateQR,
                ),
                const SizedBox(height: 12),
                _PairButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan QR Code',
                  glowAnim: _glowAnim,
                  onTap: _onOpenScanner,
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const Spacer(),
          _AwaitingIndicator(glowAnim: _glowAnim, awaitCtrl: _awaitCtrl),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGenerating() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _TopBar(onBack: _goBack, onSkip: widget.onSkip),
          const SizedBox(height: 40),
          const Text(
            'Pair with Partner',
            style: TextStyle(
              color: _kText,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.75,
              height: 1.20,
            ),
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: 0.80,
            child: const Text(
              'Enter the celestial gateway. Scan the portal\ncode to sync your hearts into eternity.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kTextSub, fontSize: 16, height: 1.63),
            ),
          ),
          const SizedBox(height: 28),
          _GlassCard(
            glowAnim: _glowAnim,
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _kPurple.withValues(alpha: 
                            0.15 + 0.10 * _glowAnim.value,
                          ),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _currentPairing == null
                        ? const SizedBox(
                            width: 180,
                            height: 180,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF131318),
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : QrImageView(
                            data: _qrData,
                            version: QrVersions.auto,
                            size: 180,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF131318),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF131318),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _kPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _kPurple.withValues(alpha: 0.28),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tag_rounded,
                        color: _kPurple.withValues(alpha: 0.6),
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentPairing?.pairingCode ??
                            '------', // ← Shows real code
                        style: const TextStyle(
                          color: _kPurple,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _PairButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan QR Code',
                  glowAnim: _glowAnim,
                  onTap: _onOpenScanner,
                ),
              ],
            ),
          ),
          const Spacer(),
          _AwaitingIndicator(
            glowAnim: _glowAnim,
            awaitCtrl: _awaitCtrl,
            pulsing: true,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildScanning() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scanner!,
          onDetect: _onBarcodeDetected,
          errorBuilder: (ctx, err, _) => _ScannerError(
            onRetry: () {
              _scanner?.dispose();
              _onOpenScanner();
            },
          ),
        ),
        Container(color: Colors.black.withValues(alpha: 0.55)),
        Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_glowAnim, _scanLineCtrl]),
            builder: (_, _) =>
                _Viewfinder(glowAnim: _glowAnim, scanLineAnim: _scanLineCtrl),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: _TopBar(
                onBack: _goBack,
                onSkip: widget.onSkip,
                darkMode: false,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 120,
          left: 20,
          right: 20,
          child: ElevatedButton(
            onPressed: _openManualEntry,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black54),
            child: const Text("Can't scan? Enter code manually"),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (_, _) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _kPurple.withValues(alpha: 
                            0.15 + 0.10 * _glowAnim.value,
                          ),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'Point camera at partner\'s QR code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: 0.55,
                    child: const Text(
                      'Code is detected automatically',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: _scanner!,
          builder: (context, value, child) => value.isRunning
              ? const SizedBox.shrink()
              : Container(
                  color: _kBg,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: _kPurple,
                      strokeWidth: 2,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildManualEntry() {
    final TextEditingController codeCtrl = TextEditingController();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enter 6‑character code',
              style: TextStyle(
                color: _kText,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtrl,
              style: const TextStyle(color: _kText, fontSize: 18),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'e.g., ABC123',
                hintStyle: const TextStyle(color: _kTextSub),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _PairButton(
              icon: Icons.check_circle_rounded,
              label: 'Verify',
              glowAnim: _glowAnim,
              onTap: () {
                final code = codeCtrl.text.trim().toUpperCase();
                if (code.length == 6) {
                  _submitManualCode(code);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a 6‑character code'),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _state = _PairingState.scanning),
              child: const Text(
                'Back to scanner',
                style: TextStyle(color: _kTextSub),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnecting() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_orbitCtrl, _glowAnim, _pulseAnim]),
              builder: (_, _) => SizedBox(
                width: 148,
                height: 148,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(148, 148),
                      painter: _OrbitPainter(
                        t: _orbitCtrl.value,
                        glow: _glowAnim.value,
                      ),
                    ),
                    Transform.scale(
                      scale: _pulseAnim.value,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _kPurple.withValues(alpha: 0.18),
                              _kPurple.withValues(alpha: 0.04),
                            ],
                          ),
                          border: Border.all(
                            color: _kPurple.withValues(alpha: 
                              0.40 + 0.20 * _glowAnim.value,
                            ),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: _kPurple,
                          size: 34,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),
            const Text(
              'Connecting…',
              style: TextStyle(
                color: _kText,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: 0.70,
              child: const Text(
                'Syncing your hearts into eternity.\nThis will only take a moment.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kTextSub, fontSize: 15, height: 1.65),
              ),
            ),
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: _orbitCtrl,
              builder: (_, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final phase = (_orbitCtrl.value + i * 0.28) % 1.0;
                  final scale =
                      0.6 +
                      0.4 *
                          (math.sin(phase * math.pi * 2) * 0.5 + 0.5).clamp(
                            0.0,
                            1.0,
                          );
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kPurple.withValues(alpha: scale),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _successAnim,
              child: AnimatedBuilder(
                animation: _glowAnim,
                builder: (_, _) => Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _kPurple.withValues(alpha: 0.18),
                        _kPurple.withValues(alpha: 0.04),
                      ],
                    ),
                    border: Border.all(
                      color: _kPurple.withValues(alpha: 
                        0.50 + 0.25 * _glowAnim.value,
                      ),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kPurple.withValues(alpha: 
                          0.30 + 0.15 * _glowAnim.value,
                        ),
                        blurRadius: 50,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: _kPurple,
                    size: 60,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
            const Text(
              'Hearts Connected ♡',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _kText,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: 0.75,
              child: const Text(
                'You\'re now paired. Your shared world\nis ready to begin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kTextSub, fontSize: 15, height: 1.65),
              ),
            ),
            const SizedBox(height: 44),
            _PairButton(
              icon: Icons.arrow_forward_rounded,
              label: 'Enter Together',
              glowAnim: _glowAnim,
              onTap: widget.onPaired,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HELPER WIDGETS (completely unchanged from your original)
// ═══════════════════════════════════════════════════════════════

class _Background extends StatelessWidget {
  const _Background({required this.glowAnim});
  final Animation<double> glowAnim;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowAnim,
      builder: (_, _) => Stack(
        children: [
          Positioned(
            left: -96,
            top: -96,
            child: Container(
              width: 384,
              height: 384,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(
                      0xFFC9BFFF,
                    ).withValues(alpha: 0.13 + 0.06 * glowAnim.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 70,
            top: 440,
            child: Opacity(
              opacity: 0.40 + 0.12 * glowAnim.value,
              child: Container(
                width: 512,
                height: 512,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFC9BFFF).withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 97,
            top: 692,
            child: Opacity(
              opacity: 0.22 + 0.08 * glowAnim.value,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFC9BFFF).withValues(alpha: 0.15),
                      Colors.transparent,
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

class _TopBar extends StatelessWidget {
  const _TopBar({this.onBack, this.onSkip, this.darkMode = true});
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final bool darkMode;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: darkMode ? 0.10 : 0.18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: darkMode ? 0.14 : 0.24),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: darkMode ? _kPurple : Colors.white,
                size: 18,
              ),
            ),
          ),
        if (onBack == null) const SizedBox(width: 40),
        const Spacer(),
        GestureDetector(
          onTap: onSkip,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: darkMode ? 0.06 : 0.14),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: darkMode
                    ? Colors.white.withValues(alpha: 0.16)
                    : const Color(0xFFCAC4D0).withValues(alpha: 0.70),
                width: 1,
              ),
            ),
            child: Text(
              'Skip',
              style: TextStyle(
                color: darkMode
                    ? Colors.white.withValues(alpha: 0.78)
                    : Colors.white.withValues(alpha: 0.80),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.10,
                height: 1.43,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.glowAnim, required this.child});
  final Animation<double> glowAnim;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowAnim,
      builder: (_, _) => ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF111712).withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 50,
                  offset: const Offset(0, 25),
                  spreadRadius: -12,
                ),
                BoxShadow(
                  color: _kPurple.withValues(alpha: 0.06 + 0.05 * glowAnim.value),
                  blurRadius: 44,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PairButton extends StatefulWidget {
  const _PairButton({
    required this.icon,
    required this.label,
    required this.glowAnim,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Animation<double> glowAnim;
  final VoidCallback onTap;
  @override
  State<_PairButton> createState() => _PairButtonState();
}

class _PairButtonState extends State<_PairButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;
  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: () {
        HapticFeedback.lightImpact();
        _pressCtrl.reverse();
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedBuilder(
          animation: widget.glowAnim,
          builder: (_, _) => Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment(0.46, -0.46),
                end: Alignment(0.54, 1.46),
                colors: [Color(0xFFC9BFFF), Color(0xFF605794)],
              ),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF8B5CF6,
                  ).withValues(alpha: 0.35 + 0.12 * widget.glowAnim.value),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: _kBtnTxt, size: 20),
                const SizedBox(width: 12),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: _kBtnTxt,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.50,
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

class _AwaitingIndicator extends StatelessWidget {
  const _AwaitingIndicator({
    required this.glowAnim,
    required this.awaitCtrl,
    this.pulsing = false,
  });
  final Animation<double> glowAnim;
  final AnimationController awaitCtrl;
  final bool pulsing;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([glowAnim, awaitCtrl]),
      builder: (_, _) {
        final pulse = pulsing
            ? Tween<double>(begin: 0.88, end: 1.0).transform(
                CurvedAnimation(
                  parent: awaitCtrl,
                  curve: Curves.easeInOut,
                ).value,
              )
            : 1.0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: pulse,
              child: Container(
                width: 56,
                height: 56,
                decoration: ShapeDecoration(
                  color: const Color(0x7F35343A),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  shadows: [
                    BoxShadow(
                      color: _kPurple.withValues(alpha: 0.18 + 0.12 * glowAnim.value),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: _kPurple.withValues(alpha: 0.75 + 0.25 * glowAnim.value),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: 0.45 + 0.15 * glowAnim.value,
              child: const Text(
                'AWAITING CONNECTION',
                style: TextStyle(
                  color: _kPurple,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 3.50,
                  height: 1.50,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.glowAnim, required this.scanLineAnim});
  final Animation<double> glowAnim;
  final AnimationController scanLineAnim;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        border: Border.all(
          color: _kPurple.withValues(alpha: 0.65 + 0.30 * glowAnim.value),
          width: 2.5,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _kPurple.withValues(alpha: 0.20 * glowAnim.value),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Container(color: Colors.transparent),
            ..._corners(),
            AnimatedBuilder(
              animation: scanLineAnim,
              builder: (_, _) {
                final y = scanLineAnim.value * 244;
                return Positioned(
                  top: y,
                  left: 12,
                  right: 12,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          _kPurple.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [
                        BoxShadow(
                          color: _kPurple.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _corners() {
    const s = 26.0, t = 3.0;
    final c = _kPurple;
    return [
      Positioned(
        top: -1,
        left: -1,
        child: _CornerArc(size: s, thickness: t, color: c, topLeft: true),
      ),
      Positioned(
        top: -1,
        right: -1,
        child: _CornerArc(
          size: s,
          thickness: t,
          color: c,
          topLeft: false,
          flipH: true,
        ),
      ),
      Positioned(
        bottom: -1,
        left: -1,
        child: _CornerArc(
          size: s,
          thickness: t,
          color: c,
          topLeft: false,
          flipV: true,
        ),
      ),
      Positioned(
        bottom: -1,
        right: -1,
        child: _CornerArc(
          size: s,
          thickness: t,
          color: c,
          topLeft: true,
          flipH: true,
          flipV: true,
        ),
      ),
    ];
  }
}

class _CornerArc extends StatelessWidget {
  const _CornerArc({
    required this.size,
    required this.thickness,
    required this.color,
    this.topLeft = true,
    this.flipH = false,
    this.flipV = false,
  });
  final double size, thickness;
  final Color color;
  final bool topLeft, flipH, flipV;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size),
    painter: _CornerPainter(
      color: color,
      thickness: thickness,
      flipH: flipH,
      flipV: flipV,
    ),
  );
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({
    required this.color,
    required this.thickness,
    this.flipH = false,
    this.flipV = false,
  });
  final Color color;
  final double thickness;
  final bool flipH, flipV;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.save();
    if (flipH) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    if (flipV) {
      canvas.translate(0, size.height);
      canvas.scale(1, -1);
    }
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CornerPainter o) => false;
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.t, required this.glow});
  final double t, glow;
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, r = size.width / 2 - 10;
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = const Color(0xFFC9BFFF).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    for (int i = 0; i < 3; i++) {
      final angle = t * 2 * math.pi + i * (2 * math.pi / 3);
      final dx = cx + r * math.cos(angle), dy = cy + r * math.sin(angle);
      final alpha =
          (0.4 + 0.6 * (math.sin(t * math.pi * 2 + i * 1.2) * 0.5 + 0.5)).clamp(
            0.2,
            1.0,
          );
      canvas.drawCircle(
        Offset(dx, dy),
        9,
        Paint()
          ..color = const Color(0xFFC9BFFF).withValues(alpha: 0.12 * alpha * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        Offset(dx, dy),
        4.0,
        Paint()..color = const Color(0xFFC9BFFF).withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter o) => o.t != t || o.glow != glow;
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, color: _kPurple, size: 52),
            const SizedBox(height: 16),
            const Text(
              'Camera unavailable',
              style: TextStyle(
                color: _kText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: 0.65,
              child: const Text(
                'Check camera permission in settings.',
                style: TextStyle(color: _kTextSub, fontSize: 14),
              ),
            ),
            const SizedBox(height: 28),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: _kPurple,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
