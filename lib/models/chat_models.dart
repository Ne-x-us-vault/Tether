import 'package:flutter/material.dart';

@immutable
class ChatThemeSpec {
  const ChatThemeSpec({
    required this.name,
    required this.start,
    required this.end,
    required this.accent,
  });

  final String name;
  final Color start;
  final Color end;
  final Color accent;
}

@immutable
class QuickMessageChipSpec {
  const QuickMessageChipSpec({
    required this.label,
    required this.message,
    required this.icon,
  });

  final String label;
  final String message;
  final IconData icon;
}

const ChatThemeSpec kDefaultChatTheme = ChatThemeSpec(
  name: 'Velvet Orbit',
  start: Color(0xFF271B4D),
  end: Color(0xFF120F24),
  accent: Color(0xFFB39DFF),
);

const List<ChatThemeSpec> kChatThemes = [
  ChatThemeSpec(
    name: 'Velvet Orbit',
    start: Color(0xFF271B4D),
    end: Color(0xFF120F24),
    accent: Color(0xFFB39DFF),
  ),
  ChatThemeSpec(
    name: 'Sunset',
    start: Color(0xFFFF6B6B),
    end: Color(0xFFFFE66D),
    accent: Color(0xFFFF8C00),
  ),
  ChatThemeSpec(
    name: 'Ocean',
    start: Color(0xFF001F3F),
    end: Color(0xFF003D82),
    accent: Color(0xFF00D4FF),
  ),
  ChatThemeSpec(
    name: 'Forest',
    start: Color(0xFF2D5016),
    end: Color(0xFF1B2F11),
    accent: Color(0xFF4ADE80),
  ),
  ChatThemeSpec(
    name: 'Blush',
    start: Color(0xFFFF6EC7),
    end: Color(0xFFC45BA0),
    accent: Color(0xFFFF9BAB),
  ),
];

const String kPrimaryChatThreadId = 'primary-thread';

// Commonly used emoji reactions (Telegram-like)
const List<String> kReactionEmojis = [
  '👍',
  '❤️',
  '😂',
  '😮',
  '😢',
  '🔥',
  '👏',
  '✨',
];

String resolveChatThreadId(Map<String, dynamic> metadata) {
  final rawThreadId = metadata['thread_id'];
  if (rawThreadId is String && rawThreadId.trim().isNotEmpty) {
    return rawThreadId.trim();
  }
  return kPrimaryChatThreadId;
}

const List<QuickMessageChipSpec> kQuickMessageChips = [
  QuickMessageChipSpec(
    label: 'Coffee?',
    message: 'Coffee together?',
    icon: Icons.local_cafe_rounded,
  ),
  QuickMessageChipSpec(
    label: 'Reached home',
    message: 'I reached home safely.',
    icon: Icons.home_rounded,
  ),
  QuickMessageChipSpec(
    label: 'Miss you',
    message: 'Missing you already.',
    icon: Icons.favorite_rounded,
  ),
];
