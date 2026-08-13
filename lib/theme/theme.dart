import 'package:flutter/material.dart';

/// Color presets for easy theme selection
class ThemePresets {
  static const List<ThemeColor> colors = [
    // Neutrals
    ThemeColor(
      name: 'Pure White',
      color: Color(0xFFFFFFFF),
      category: 'Neutral',
    ),
    ThemeColor(
      name: 'Off White',
      color: Color(0xFFFAFAFA),
      category: 'Neutral',
    ),
    ThemeColor(
      name: 'Light Gray',
      color: Color(0xFFF0F0F0),
      category: 'Neutral',
    ),
    ThemeColor(name: 'Gray', color: Color(0xFFE8E8E8), category: 'Neutral'),

    // Blues
    ThemeColor(name: 'Sky Blue', color: Color(0xFFE3F2FD), category: 'Blue'),
    ThemeColor(name: 'Light Blue', color: Color(0xFFBBDEFB), category: 'Blue'),
    ThemeColor(name: 'Cerulean', color: Color(0xFF81D4FA), category: 'Blue'),
    ThemeColor(name: 'Ocean Blue', color: Color(0xFF4FC3F7), category: 'Blue'),

    // Purples
    ThemeColor(
      name: 'Light Purple',
      color: Color(0xFFF3E5F5),
      category: 'Purple',
    ),
    ThemeColor(name: 'Lavender', color: Color(0xFFE1BEE7), category: 'Purple'),
    ThemeColor(name: 'Orchid', color: Color(0xFFCE93D8), category: 'Purple'),
    ThemeColor(name: 'Violet', color: Color(0xFFBA68C8), category: 'Purple'),

    // Pinks
    ThemeColor(name: 'Light Pink', color: Color(0xFFFCE4EC), category: 'Pink'),
    ThemeColor(name: 'Soft Pink', color: Color(0xFFF8BBD0), category: 'Pink'),
    ThemeColor(name: 'Rose', color: Color(0xFFF48FB1), category: 'Pink'),
    ThemeColor(name: 'Hot Pink', color: Color(0xFFF06292), category: 'Pink'),

    // Greens
    ThemeColor(name: 'Mint', color: Color(0xFFE0F2F1), category: 'Green'),
    ThemeColor(
      name: 'Light Green',
      color: Color(0xFFC8E6C9),
      category: 'Green',
    ),
    ThemeColor(name: 'Sage', color: Color(0xFFA5D6A7), category: 'Green'),
    ThemeColor(name: 'Forest', color: Color(0xFF81C784), category: 'Green'),

    // Oranges
    ThemeColor(name: 'Peach', color: Color(0xFFFFE0B2), category: 'Orange'),
    ThemeColor(name: 'Apricot', color: Color(0xFFFFCC80), category: 'Orange'),
    ThemeColor(name: 'Tangerine', color: Color(0xFFFFB74D), category: 'Orange'),
    ThemeColor(name: 'Orange', color: Color(0xFFFFA726), category: 'Orange'),

    // Reds
    ThemeColor(name: 'Light Coral', color: Color(0xFFFFCDD2), category: 'Red'),
    ThemeColor(name: 'Salmon', color: Color(0xFFEF9A9A), category: 'Red'),
    ThemeColor(name: 'Coral', color: Color(0xFFE57373), category: 'Red'),
    ThemeColor(name: 'Red', color: Color(0xFFEF5350), category: 'Red'),

    // Teals
    ThemeColor(name: 'Cyan', color: Color(0xFFB2EBF2), category: 'Teal'),
    ThemeColor(name: 'Turquoise', color: Color(0xFF80DEEA), category: 'Teal'),
    ThemeColor(name: 'Teal', color: Color(0xFF4DD0E1), category: 'Teal'),
    ThemeColor(name: 'Deep Teal', color: Color(0xFF26C6DA), category: 'Teal'),

    // Yellows
    ThemeColor(name: 'Cream', color: Color(0xFFFFFDE7), category: 'Yellow'),
    ThemeColor(
      name: 'Light Yellow',
      color: Color(0xFFFFF9C4),
      category: 'Yellow',
    ),
    ThemeColor(name: 'Yellow', color: Color(0xFFFFF59D), category: 'Yellow'),
    ThemeColor(name: 'Gold', color: Color(0xFFFFE082), category: 'Yellow'),
  ];

  /// Get colors grouped by category
  static Map<String, List<ThemeColor>> get colorsByCategory {
    final Map<String, List<ThemeColor>> grouped = {};
    for (final color in colors) {
      grouped.putIfAbsent(color.category, () => []).add(color);
    }
    return grouped;
  }

  /// Find a color by hex value (for saving/loading)
  static ThemeColor? findColorByValue(int colorValue) {
    try {
      return colors.firstWhere((c) => c.color.toARGB32() == colorValue);
    } catch (_) {
      return null;
    }
  }
}

/// Represents a theme color with metadata
class ThemeColor {
  final String name;
  final Color color;
  final String category;

  const ThemeColor({
    required this.name,
    required this.color,
    required this.category,
  });

  /// Convert color value to string for storage
  String toStorageString() => color.toARGB32().toString();

  /// Get hex string representation
  String toHexString() =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

/// IG Design tokens for consistent styling
class IGDesignTokens {
  // Backgrounds
  static const Color bg = Color(0xFFFFFFFF);
  static const Color scaffoldBg = Color(0xFFFFFFFF);
  static const Color headerBg = Color(0xFFFFFFFF);

  // Borders
  static const Color headerBorder = Color(0xFFDBDBDB);
  static const Color divider = Color(0xFFDBDBDB);
  static const Color inputBorder = Color(0xFFDBDBDB);
  static const Color themBubbleBorder = Color(0xFFE0E0E0);
  static const Color reactionBorder = Color(0xFFDBDBDB);
  static const Color actionSheetItemBorder = Color(0xFFF0F0F0);

  // Text
  static const Color textPrimary = Color(0xFF262626);
  static const Color textSecondary = Color(0xFF8E8E8E);
  static const Color textOnBlue = Color(0xFFFFFFFF);
  static const Color textOnThem = Color(0xFF262626);

  // Semantic
  static const Color blue = Color(0xFF3797F0);
  static const Color blueBubble = Color(0xFF3797F0);
  static const Color themBubble = Color(0xFFF0F0F0);
  static const Color errorRed = Color(0xFFED4956);
  static const Color starYellow = Color(0xFFFFC107);

  // Surfaces
  static const Color reactionBg = Color(0xFFFFFFFF);
  static const Color inputBg = Color(0xFFF0F0F0);
  static const Color composerBg = Color(0xFFFFFFFF);
  static const Color replyPillBg = Color(0xFFF7F7F7);
  static const Color pinnedBg = Color(0xFFFAFAFA);
  static const Color typingBubbleBg = Color(0xFFF0F0F0);
  static const Color quickPickerBg = Color(0xFFFFFFFF);
  static const Color actionSheetBg = Color(0xFFFFFFFF);
  static const Color emojiSelectedBg = Color(0xFFE8F4FD);

  // Skeleton
  static const Color skeletonBase = Color(0xFFEEEEEE);
  static const Color skeletonHighlight = Color(0xFFF5F5F5);

  // Font sizes
  static const double fontSizeXs = 10.0;
  static const double fontSizeSm = 12.0;
  static const double fontSizeMd = 14.0;
  static const double fontSizeLg = 16.0;

  // Border radius
  static const double radiusBubble = 20.0;
  static const double radiusBubbleTail = 4.0;
}
