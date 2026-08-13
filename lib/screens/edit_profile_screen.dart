import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';

const _kBgDark = Color(0xFF09090B);
const _kCardBg = Color(0xFF131318);
const _kCardBorder = Color(0xFF1C1C24);
const _kPurple = Color(0xFF8B5CF6);
const _kPurpleViv = Color(0xFFC084FC);
const _kPink = Color(0xFFF43F5E);

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _supabase = SupabaseService();
  final _nameController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _avatarUrl;
  File? _selectedImage;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _supabase.getMyProfile();
      if (profile != null && mounted) {
        setState(() {
          _profile = profile;
          _nameController.text = profile.preferences['partner_nickname'] ?? '';
          _avatarUrl = profile.avatarUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[EditProfile] Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null && mounted) {
        // Hide system UI (immersive mode) so time/battery/signal icons are completely hidden during cropping
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

        CroppedFile? croppedFile;
        try {
          croppedFile = await ImageCropper().cropImage(
            sourcePath: picked.path,
            aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'Crop Avatar',
                toolbarColor: _kCardBg,
                toolbarWidgetColor: _kPurpleViv,
                initAspectRatio: CropAspectRatioPreset.square,
                lockAspectRatio: true,
                hideBottomControls: false,
              ),
              IOSUiSettings(
                title: 'Crop Avatar',
                aspectRatioLockEnabled: true,
                resetAspectRatioEnabled: false,
              ),
            ],
          );
        } finally {
          // Always restore standard status and navigation bars immediately
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
        }

        final path = croppedFile?.path;
        if (path != null && mounted) {
          setState(() {
            _selectedImage = File(path);
          });
          HapticFeedback.lightImpact();
        }
      }
    } catch (e) {
      debugPrint('[EditProfile] Error picking/cropping image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select image: $e'), backgroundColor: _kPink),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nickname cannot be empty ✨'), backgroundColor: _kPink),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final userId = _supabase.currentUserId;
      if (userId == null) throw Exception('Not logged in');

      String? uploadedUrl = _avatarUrl;
      if (_selectedImage != null) {
        uploadedUrl = await _supabase.uploadAvatar(userId, _selectedImage!.path);
      }

      await _supabase.updateProfile(
        avatarUrl: uploadedUrl,
        preferences: {
          ...(_profile?.preferences ?? {}),
          'partner_nickname': name,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully ✨'), backgroundColor: _kPurple),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('[EditProfile] Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: _kPink),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Edit Nickname',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: _kPurpleViv, strokeWidth: 2.5),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: const Text(
                    'Save',
                    style: TextStyle(color: _kPurpleViv, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kPurple))
          : Stack(
              children: [
                Positioned(
                  top: -50,
                  left: -50,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [_kPurple.withValues(alpha: 0.15), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar picker
                      GestureDetector(
                        onTap: _isSaving ? null : _pickImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: _kPurple.withValues(alpha: 0.4), width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kPurple.withValues(alpha: 0.2),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _selectedImage != null
                                    ? Image.file(_selectedImage!, fit: BoxFit.cover)
                                    : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: _avatarUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              color: _kCardBg,
                                              child: const Center(
                                                child: CircularProgressIndicator(color: _kPurple, strokeWidth: 2),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => _buildFallbackAvatar(),
                                          )
                                        : _buildFallbackAvatar()),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _kPurpleViv,
                                shape: BoxShape.circle,
                                border: Border.all(color: _kBgDark, width: 3),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to change profile picture',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                      ),
                      const SizedBox(height: 36),

                      // Input fields
                      _buildInputField(
                        controller: _nameController,
                        label: 'Partner Nickname',
                        icon: Icons.favorite_border_rounded,
                        helperText: 'What do you lovingly call your partner?',
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFallbackAvatar() {
    final initial = _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '💖';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_kPurple, _kCardBg], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(
        child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? helperText,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kCardBorder),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: maxLines == 1 ? Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 20) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(18),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(helperText, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
          ),
        ],
      ],
    );
  }
}
