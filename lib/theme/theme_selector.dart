import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'theme.dart';

/// Simplified single-page theme selector with color grid and image option
class ThemeSelectorPage extends StatefulWidget {
  final Color currentBgColor;
  final String? currentBgImagePath;
  final Function(Color) onColorChanged;
  final Function(String?) onImageChanged;

  const ThemeSelectorPage({
    super.key,
    required this.currentBgColor,
    required this.currentBgImagePath,
    required this.onColorChanged,
    required this.onImageChanged,
  });

  @override
  State<ThemeSelectorPage> createState() => _ThemeSelectorPageState();
}

class _ThemeSelectorPageState extends State<ThemeSelectorPage> {
  late Color _selectedColor;
  late String? _selectedImagePath;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentBgColor;
    _selectedImagePath = widget.currentBgImagePath;
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        setState(() => _selectedImagePath = path);
        widget.onImageChanged(path);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _clearImage() {
    setState(() => _selectedImagePath = null);
    widget.onImageChanged(null);
  }

  void _selectColor(ThemeColor themeColor) {
    setState(() => _selectedColor = themeColor.color);
    widget.onColorChanged(themeColor.color);
    // Clear image when color is selected
    if (_selectedImagePath != null) {
      _clearImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IGDesignTokens.scaffoldBg,
      appBar: AppBar(
        backgroundColor: IGDesignTokens.headerBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: IGDesignTokens.textPrimary,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Customize Theme',
          style: TextStyle(
            color: IGDesignTokens.textPrimary,
            fontSize: IGDesignTokens.fontSizeLg,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: IGDesignTokens.headerBorder, height: 0.5),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current background preview
            _buildBackgroundPreview(),
            const SizedBox(height: 32),

            // Color section
            _buildColorSection(),
            const SizedBox(height: 32),

            // Image section
            _buildImageSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Background Preview',
          style: TextStyle(
            fontSize: IGDesignTokens.fontSizeMd,
            fontWeight: FontWeight.w600,
            color: IGDesignTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: IGDesignTokens.divider, width: 1),
            color: _selectedColor,
            image: _selectedImagePath != null
                ? DecorationImage(
                    image: FileImage(File(_selectedImagePath!)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _selectedImagePath == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _selectedColor.toString(),
                        style: TextStyle(
                          fontSize: IGDesignTokens.fontSizeSm,
                          color: _selectedColor.computeLuminance() > 0.5
                              ? Colors.black54
                              : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildColorSection() {
    final colorsByCategory = ThemePresets.colorsByCategory;
    final categories = colorsByCategory.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Colors',
          style: TextStyle(
            fontSize: IGDesignTokens.fontSizeMd,
            fontWeight: FontWeight.w600,
            color: IGDesignTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        ...categories.map((category) {
          final colors = colorsByCategory[category]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: TextStyle(
                  fontSize: IGDesignTokens.fontSizeSm,
                  fontWeight: FontWeight.w500,
                  color: IGDesignTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: colors
                    .map((color) => _buildColorTile(color))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildColorTile(ThemeColor themeColor) {
    final isSelected =
        _selectedColor.toARGB32() == themeColor.color.toARGB32() &&
        _selectedImagePath == null;

    return GestureDetector(
      onTap: () => _selectColor(themeColor),
      child: Tooltip(
        message: themeColor.name,
        child: Container(
          decoration: BoxDecoration(
            color: themeColor.color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? IGDesignTokens.blue : IGDesignTokens.divider,
              width: isSelected ? 3 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: IGDesignTokens.blue.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
          child: isSelected
              ? Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: themeColor.color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    size: 20,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Background Image',
          style: TextStyle(
            fontSize: IGDesignTokens.fontSizeMd,
            fontWeight: FontWeight.w600,
            color: IGDesignTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedImagePath == null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: IGDesignTokens.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _pickImage,
              icon: const Icon(
                Icons.add_photo_alternate_rounded,
                size: 20,
                color: Colors.white,
              ),
              label: const Text(
                'Select Image',
                style: TextStyle(
                  fontSize: IGDesignTokens.fontSizeMd,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          )
        else ...[
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: IGDesignTokens.divider, width: 1),
              image: DecorationImage(
                image: FileImage(File(_selectedImagePath!)),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IGDesignTokens.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _pickImage,
                  icon: const Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: IGDesignTokens.fontSizeSm,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: IGDesignTokens.errorRed),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _clearImage,
                  icon: const Icon(
                    Icons.delete_rounded,
                    size: 18,
                    color: IGDesignTokens.errorRed,
                  ),
                  label: const Text(
                    'Remove',
                    style: TextStyle(
                      fontSize: IGDesignTokens.fontSizeSm,
                      fontWeight: FontWeight.w600,
                      color: IGDesignTokens.errorRed,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
