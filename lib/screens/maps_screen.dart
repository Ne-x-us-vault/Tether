import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show kNavBarPad;
import '../services/location_sync_service.dart';
import '../services/supabase_service.dart';

const Color _kBg = Color(0xFF08080C);
const Color _kAccent = Color(0xFFC0A9FF);
const Color _kPartner = Color(0xFFFF9BAE);
const Color _kSurface = Color(0xAA12121A);
const Color _kBorder = Color(0x33FFFFFF);

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final SupabaseService _sb = SupabaseService();
  final LocationSyncService _locationSync = LocationSyncService();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<List<UserProfile>>? _profileSub;
  UserProfile? _me;
  UserProfile? _partner;
  bool _loading = true;
  bool _hasInitiallyCentered = false;

  // UI State
  bool _isSearching = false;
  List<dynamic> _searchResults = [];
  LatLng? _selectedPlace;
  String? _selectedPlaceName;
  String? _selectedPinId;
  double _currentRotation = 0.0;
  Timer? _debounceTimer;
  bool _followMode = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initFlow();
  }

  Future<void> _initFlow() async {
    try {
      await _loadProfiles();
      unawaited(_locationSync.ensurePermissions(prompt: true));
    } catch (e) {
      debugPrint('Flow init error: $e');
    }
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });

    try {
      final pairing = await _resolvePairing();
      if (pairing == null) throw Exception('Pairing required.');

      await _locationSync.syncNow().timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );

      final meP = await _sb.getMyProfile();
      final paP = await _sb.getPartnerProfile(pairing.id);

      await _profileSub?.cancel();
      _profileSub = _sb
          .watchProfiles([
            pairing.user1Id,
            if (pairing.user2Id != null) pairing.user2Id!,
          ])
          .listen(_handleLiveProfiles);

      if (!mounted) return;
      setState(() {
        _me = meP;
        _partner = paP;
        _loading = false;
      });

      if (!_hasInitiallyCentered) _recenterNow(zoom: 14.5);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      debugPrint('Load profiles error: $error');
    }
  }

  void _handleLiveProfiles(List<UserProfile> profiles) {
    if (!mounted) return;
    final currentUserId = _sb.currentUserId;
    UserProfile? me;
    UserProfile? partner;
    for (final profile in profiles) {
      if (profile.id == currentUserId) {
        me = profile;
      } else {
        partner ??= profile;
      }
    }
    setState(() {
      _me = me ?? _me;
      _partner = partner ?? _partner;
    });
    if (!_hasInitiallyCentered || _followMode) _recenterNow();
  }

  void _recenterNow({double? zoom}) {
    if (!mounted) return;
    final target = _selectedPlace ?? _cameraCenter;
    if (target == null || !target.latitude.isFinite) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        // Safe access to camera center and zoom
        final zoomLevel = zoom ?? _mapController.camera.zoom;
        if (target.latitude.isFinite && target.longitude.isFinite) {
          _mapController.move(target, zoomLevel);
          _hasInitiallyCentered = true;
        }
      } catch (e) {
        debugPrint('Map not ready: $e');
      }
    });
  }

  Future<Pairing?> _resolvePairing() async {
    final active = await _sb.getActivePairing();
    if (active != null) return active;
    final prefs = await SharedPreferences.getInstance();
    final pid = prefs.getString('active_pairing_id');
    return (pid != null && pid.isNotEmpty) ? _sb.getPairing(pid) : null;
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 600),
      () => _searchPlaces(query),
    );
  }

  Future<void> _searchPlaces(String query) async {
    if (!mounted || query.trim().isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    try {
      // Add viewbox and location bias for better results (Google Maps style)
      final center = _mapController.camera.center;
      String url =
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=10&addressdetails=1';

      // Bias results towards the current map center
      if (center.latitude.isFinite) {
        final bias = '&lat=${center.latitude}&lon=${center.longitude}&zoom=12';
        url += bias;
      }

      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'lovit_app'})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && mounted) {
        setState(() => _searchResults = json.decode(response.body));
      }
    } catch (_) {}
  }

  Future<void> _launchDirections(LatLng dest) async {
    final lat = dest.latitude;
    final lon = dest.longitude;
    final List<String> urls = [
      'google.navigation:q=$lat,$lon&mode=d',
      'comgooglemaps://?daddr=$lat,$lon&directionsmode=driving',
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
    ];

    bool launched = false;
    for (final url in urls) {
      try {
        if (await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        )) {
          launched = true;
          break;
        }
      } catch (_) {}
    }

    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open Maps app.')));
    }
  }

  void _handlePinTap(String id) {
    if (id == 'partner' && _partnerPoint != null) {
      _showPartnerDirectionDialog();
    } else {
      setState(() => _selectedPinId = (_selectedPinId == id) ? null : id);
    }
  }

  void _showPartnerDirectionDialog() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF15141A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Get Directions?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Navigate to ${_me?.preferences['partner_nickname'] ?? _partner?.displayName ?? 'your partner'}\'s current location?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9BAB), // Partner accent color
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              if (_partnerPoint != null) {
                _launchDirections(_partnerPoint!);
              }
            },
            child: const Text(
              'START',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _selectResult(dynamic result) {
    final lat = double.tryParse(result['lat']?.toString() ?? '');
    final lon = double.tryParse(result['lon']?.toString() ?? '');
    if (lat == null || lon == null || !lat.isFinite) return;

    setState(() {
      _selectedPlace = LatLng(lat, lon);
      _selectedPlaceName = result['display_name']?.toString() ?? 'Location';
      _isSearching = false;
      _searchResults = [];
      _searchController.clear();
      _selectedPinId = null;
      _followMode = false;
    });
    _recenterNow(zoom: 16.0);
    FocusScope.of(context).unfocus();
  }

  LatLng? get _myPoint =>
      _toLatLng(_me?.currentLatitude, _me?.currentLongitude);
  LatLng? get _partnerPoint =>
      _toLatLng(_partner?.currentLatitude, _partner?.currentLongitude);
  LatLng? _toLatLng(double? lat, double? lon) =>
      (lat != null && lon != null && lat.isFinite && lon.isFinite)
      ? LatLng(lat, lon)
      : null;

  LatLng? get _cameraCenter {
    final pts = <LatLng>[];
    if (_myPoint != null) pts.add(_myPoint!);
    if (_partnerPoint != null) pts.add(_partnerPoint!);
    if (pts.isEmpty) return null;
    if (pts.length == 1) return pts.first;
    return LatLng(
      pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length,
      pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length,
    );
  }

  double? _distKm(LatLng? p1, LatLng? p2) {
    if (p1 == null || p2 == null) return null;
    if (!p1.latitude.isFinite ||
        !p1.longitude.isFinite ||
        !p2.latitude.isFinite ||
        !p2.longitude.isFinite) {
      return null;
    }
    const r = 6371.0;
    final dLat = (p2.latitude - p1.latitude) * (math.pi / 180);
    final dLon = (p2.longitude - p1.longitude) * (math.pi / 180);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(p1.latitude * math.pi / 180) *
            math.cos(p2.latitude * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    if (a < 0 || a > 1) return 0.0; // Safety for math errors
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final top = MediaQuery.of(context).padding.top;
    final distPartner = _distKm(_myPoint, _partnerPoint);
    final distSearch = _distKm(_myPoint, _selectedPlace);

    return Scaffold(
      backgroundColor: _kBg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. STUNNING DARK MAP
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                _kBg.withValues(alpha: 0.1),
                BlendMode.darken,
              ),
              child: _LiveMapSurface(
                controller: _mapController,
                me: _myPoint,
                partner: _partnerPoint,
                meProfile: _me,
                partnerProfile: _partner,
                selectedPlace: _selectedPlace,
                selectedPinId: _selectedPinId,
                onPinTap: _handlePinTap,
                onMapEvent: (evt) {
                  if (!mounted) return;
                  if (evt is MapEventMove &&
                      evt.source != MapEventSource.mapController) {
                    if (_followMode) setState(() => _followMode = false);
                  }
                  if ((evt.camera.rotation - _currentRotation).abs() > 0.05) {
                    setState(() => _currentRotation = evt.camera.rotation);
                  }
                },
              ),
            ),
          ),

          // 2. PREMIUM OVERLAY (VIGNETTE & GLOW)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      _kBg.withValues(alpha: 0.2),
                      _kBg.withValues(alpha: 0.9),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. FLOATING GLASS HEADER
          Positioned(
            top: top + 16,
            left: 20,
            right: 20,
            child: Column(
              children: [
                _PremiumGlassPanel(
                  child: Row(
                    children: [
                      _AnimatedHeaderIcon(
                        isSearching: _isSearching,
                        onBack: () => setState(() {
                          _isSearching = false;
                          _searchResults = [];
                          _searchController.clear();
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          onTap: () => setState(() => _isSearching = true),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Where to?',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_selectedPlace != null)
                        _ActionIcon(
                          icon: Icons.close_rounded,
                          color: Colors.white60,
                          onTap: () => setState(() {
                            _selectedPlace = null;
                          }),
                        )
                      else ...[
                        if (_currentRotation.abs() > 0.1)
                          _ActionIcon(
                            icon: Icons.explore_rounded,
                            color: _kAccent,
                            onTap: () => _mapController.rotate(0),
                          ),
                        _ActionIcon(
                          icon: _followMode
                              ? Icons.gps_fixed_rounded
                              : Icons.my_location_rounded,
                          color: _followMode ? _kAccent : Colors.white60,
                          onTap: () {
                            setState(() => _followMode = !_followMode);
                            if (_followMode) _recenterNow(zoom: 14.5);
                          },
                        ),
                        _ActionIcon(
                          icon: Icons.sync_rounded,
                          color: Colors.white60,
                          onTap: _loadProfiles,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!_isSearching &&
                    _selectedPlace == null &&
                    distPartner != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _MiniBadge(
                      icon: Icons.favorite_rounded,
                      color: _kPartner,
                      label: '${_formatDist(distPartner)} away',
                    ),
                  ),
                if (_isSearching && _searchResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _PremiumGlassPanel(
                      padding: EdgeInsets.zero,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, _) =>
                              Divider(color: Colors.white10, height: 1),
                          itemBuilder: (context, i) {
                            final res = _searchResults[i];
                            return ListTile(
                              leading: const Icon(
                                Icons.place_rounded,
                                color: Colors.white38,
                                size: 18,
                              ),
                              title: Text(
                                res['display_name']?.toString() ?? '...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onTap: () => _selectResult(res),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 4. DESTINATION HUB (BOTTOM CARD)
          if (_selectedPlace != null && !_isSearching)
            Positioned(
              bottom: kNavBarPad + 24,
              left: 20,
              right: 20,
              child: _PremiumGlassPanel(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _kAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _kAccent.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: _kAccent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DESTINATION',
                                style: TextStyle(
                                  color: _kAccent.withValues(alpha: 0.6),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedPlaceName ?? '...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (distSearch != null)
                          _Badge(
                            label: _formatDist(distSearch),
                            color: Colors.greenAccent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _PrimaryButton(
                      label: 'START NAVIGATION',
                      icon: Icons.directions_rounded,
                      color: _kAccent,
                      onTap: () => _launchDirections(_selectedPlace!),
                    ),
                  ],
                ),
              ),
            ),

          if (_loading) const Center(child: _PulsingLoader()),
        ],
      ),
    );
  }

  String _formatDist(double? km) {
    if (km == null || !km.isFinite) return '--';
    return (km < 1 ? '${(km * 1000).toInt()}m' : '${km.toStringAsFixed(1)}km');
  }
}

class _LiveMapSurface extends StatelessWidget {
  const _LiveMapSurface({
    required this.controller,
    this.me,
    this.partner,
    this.meProfile,
    this.partnerProfile,
    this.selectedPlace,
    this.selectedPinId,
    this.onPinTap,
    this.onMapEvent,
  });
  final MapController controller;
  final LatLng? me, partner, selectedPlace;
  final UserProfile? meProfile, partnerProfile;
  final String? selectedPinId;
  final Function(String)? onPinTap;
  final Function(MapEvent)? onMapEvent;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg, // Ensure the container behind the map is dark
      child: FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: const LatLng(20.5, 78.9),
          initialZoom: 14.5,
          minZoom: 3.0,
          maxZoom: 18.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
          onMapEvent: onMapEvent,
          onTap: (_, _) => onPinTap?.call(''),
          // Prevent scrolling into the white void at the top/bottom
          cameraConstraint: CameraConstraint.contain(
            bounds: LatLngBounds(
              const LatLng(-90, -180),
              const LatLng(90, 180),
            ),
          ),
        ),
        children: [
          // 1. BASE DARK LAYER (No Labels for speed & style)
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'lovit',
            keepBuffer: 4, // Pre-loads more tiles ahead of scrolling
          ),
          // 2. HIGH-DETAIL LABELS LAYER (Ensures names are visible)
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/dark_only_labels/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'lovit',
          ),
          if (me != null &&
              me!.latitude.isFinite &&
              (selectedPlace != null || partner != null))
            PolylineLayer(
              polylines: [
                if ((selectedPlace ?? partner!).latitude.isFinite)
                  Polyline(
                    points: [me!, selectedPlace ?? partner!],
                    color: _kAccent.withValues(alpha: 0.3),
                    strokeWidth: 4,
                    borderStrokeWidth: 2,
                    borderColor: _kAccent.withValues(alpha: 0.1),
                  ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (me != null && me!.latitude.isFinite)
                Marker(
                  point: me!,
                  width: 100,
                  height: 100,
                  child: _AvatarPin(
                    profile: meProfile,
                    color: _kAccent,
                    label: 'YOU',
                    isSelected: selectedPinId == 'me',
                    onTap: () => onPinTap?.call('me'),
                  ),
                ),
              if (partner != null && partner!.latitude.isFinite)
                Marker(
                  point: partner!,
                  width: 100,
                  height: 100,
                  child: _AvatarPin(
                    profile: partnerProfile,
                    color: _kPartner,
                    label:
                        (meProfile?.preferences['partner_nickname'] ??
                                partnerProfile?.displayName ??
                                'PARTNER')
                            .toUpperCase(),
                    isSelected: selectedPinId == 'partner',
                    onTap: () => onPinTap?.call('partner'),
                    pulse: true,
                  ),
                ),
              if (selectedPlace != null && selectedPlace!.latitude.isFinite)
                Marker(
                  point: selectedPlace!,
                  width: 60,
                  height: 60,
                  child: const _TargetPin(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarPin extends StatelessWidget {
  const _AvatarPin({
    this.profile,
    required this.color,
    required this.label,
    this.isSelected = false,
    this.pulse = false,
    this.onTap,
  });
  final UserProfile? profile;
  final Color color;
  final String label;
  final bool isSelected;
  final bool pulse;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (pulse) _SonarPulse(color: color),
          _BatteryBubble(battery: profile?.batteryLevel, isVisible: isSelected),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: _kSurface,
                  backgroundImage: profile?.avatarUrl != null
                      ? NetworkImage(profile!.avatarUrl!)
                      : null,
                  child: profile?.avatarUrl == null
                      ? Icon(Icons.person_rounded, color: color, size: 20)
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              _GlassTag(label: label, color: color),
            ],
          ),
        ],
      ),
    );
  }
}

class _BatteryBubble extends StatelessWidget {
  const _BatteryBubble({this.battery, required this.isVisible});
  final int? battery;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      top: isVisible ? -10 : 10,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isVisible ? 1.0 : 0.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.battery_3_bar_rounded,
                color: (battery ?? 0) > 20
                    ? Colors.greenAccent
                    : Colors.redAccent,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                '${battery ?? 0}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassTag extends StatelessWidget {
  const _GlassTag({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SonarPulse extends StatefulWidget {
  const _SonarPulse({required this.color});
  final Color color;
  @override
  State<_SonarPulse> createState() => _SonarPulseState();
}

class _SonarPulseState extends State<_SonarPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
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
      builder: (_, _) => Container(
        width: 40 + (60 * _ctrl.value),
        height: 40 + (60 * _ctrl.value),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.color.withValues(alpha: 1 - _ctrl.value),
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _TargetPin extends StatelessWidget {
  const _TargetPin();
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.greenAccent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
        ),
        const Icon(
          Icons.location_on_rounded,
          color: Colors.greenAccent,
          size: 30,
        ),
      ],
    );
  }
}

class _PremiumGlassPanel extends StatelessWidget {
  const _PremiumGlassPanel({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 40),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _AnimatedHeaderIcon extends StatelessWidget {
  const _AnimatedHeaderIcon({required this.isSearching, required this.onBack});
  final bool isSearching;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSearching ? onBack : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Icon(
          isSearching ? Icons.arrow_back_ios_new_rounded : Icons.search_rounded,
          color: _kAccent,
          key: ValueKey(isSearching),
          size: 20,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.icon,
    required this.color,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.8)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingLoader extends StatefulWidget {
  const _PulsingLoader();
  @override
  State<_PulsingLoader> createState() => _PulsingLoaderState();
}

class _PulsingLoaderState extends State<_PulsingLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: _kAccent,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: _kAccent, blurRadius: 20)],
        ),
      ),
    );
  }
}
