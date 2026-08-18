import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_service.dart';
import '../services/encryption_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import 'image_editor_screen.dart';
import 'image_viewer_screen.dart';
import '../services/call_service.dart';
import '../services/notification_service.dart';
import '../widgets/secure_media_image.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IG DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────
class _IG {
  static const bg = Color(0xFFFFFFFF);
  static const scaffoldBg = Color(0xFFFFFFFF);
  static const headerBg = Color(0xFF1F1F1F);
  static const headerBorder = Color(0xFF333333);
  static const headerText = Color(0xFFFFFFFF);
  static const headerSubtext = Color(0xFFB0B0B0);
  static const blue = Color(0xFF3797F0);
  static const textPrimary = Color(0xFF262626);
  static const textSecondary = Color(0xFF8E8E8E);
  static const divider = Color(0xFFDBDBDB);
  static const inputBg = Color(0xFFF0F0F0);
  static const skeletonBase = Color(0xFFEEEEEE);
  static const skeletonHighlight = Color(0xFFF5F5F5);
  static const errorRed = Color(0xFFED4956);

  static const fontSizeXs = 10.0;
  static const fontSizeSm = 12.0;
  static const fontSizeMd = 14.0;
  static const fontSizeLg = 16.0;

  static const radiusBubble = 20.0;
  static const radiusBubbleTail = 4.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK EMOJI LIST
// ─────────────────────────────────────────────────────────────────────────────
const _kQuickEmojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];
const _kEmojiCategories = [
  {
    'icon': '❤️',
    'label': 'Hearts',
    'emojis': [
      '❤️',
      '🧡',
      '💛',
      '💚',
      '💙',
      '💜',
      '🖤',
      '🤍',
      '🤎',
      '💔',
      '❤️‍🔥',
      '💕',
      '💞',
      '💓',
      '💗',
      '💖',
      '💘',
      '💝',
      '💟',
      '♥️',
      '❣️',
      '💌',
      '💋',
      '😍',
      '🥰',
      '😘',
      '😻',
      '💑',
      '👫',
      '💏',
      '🌹',
      '🌷',
      '💐',
      '🫀',
      '🫶',
      '🤗',
    ],
  },
  {
    'icon': '😊',
    'label': 'Smileys',
    'emojis': [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '😂',
      '🤣',
      '😊',
      '😇',
      '🙂',
      '🙃',
      '😉',
      '😌',
      '😋',
      '😛',
      '😝',
      '😜',
      '🤪',
      '😎',
      '🤩',
      '🥳',
      '😏',
      '😒',
      '😞',
      '😔',
      '😟',
      '😕',
      '🙁',
      '😣',
      '😖',
      '😫',
      '😩',
      '🥺',
      '😢',
      '😭',
      '😤',
      '😠',
      '😡',
      '🤬',
      '🤯',
      '😳',
      '🥵',
      '🥶',
      '😱',
      '😨',
      '😰',
      '😥',
      '🤔',
      '🤭',
      '🤫',
      '🤥',
      '😶',
      '😐',
      '😑',
      '😬',
      '🙄',
      '😯',
      '😮',
      '😲',
    ],
  },
  {
    'icon': '👋',
    'label': 'People',
    'emojis': [
      '👋',
      '🤚',
      '🖐',
      '✋',
      '🖖',
      '👌',
      '🤌',
      '🤏',
      '✌️',
      '🤞',
      '🤟',
      '🤘',
      '🤙',
      '👈',
      '👉',
      '👆',
      '👇',
      '☝️',
      '👍',
      '👎',
      '✊',
      '👊',
      '🤛',
      '🤜',
      '👏',
      '🙌',
      '👐',
      '🤲',
      '🤝',
      '🙏',
      '✍️',
      '💅',
      '💪',
    ],
  },
  {
    'icon': '🐶',
    'label': 'Animals',
    'emojis': [
      '🐶',
      '🐱',
      '🐭',
      '🐹',
      '🐰',
      '🦊',
      '🐻',
      '🐼',
      '🐨',
      '🐯',
      '🦁',
      '🐮',
      '🐷',
      '🐸',
      '🐵',
      '🐔',
      '🐧',
      '🐦',
      '🦅',
      '🦆',
      '🦉',
      '🦋',
      '🐛',
      '🐜',
      '🐝',
      '🐞',
      '🦗',
      '🕷️',
      '🦂',
      '🐢',
      '🐍',
      '🦎',
      '🦖',
      '🦕',
      '🐙',
      '🦑',
      '🦐',
      '🦞',
      '🦀',
      '🐡',
      '🐠',
      '🐟',
      '🐬',
      '🐳',
      '🐋',
    ],
  },
  {
    'icon': '🍎',
    'label': 'Food',
    'emojis': [
      '🍎',
      '🍊',
      '🍋',
      '🍌',
      '🍉',
      '🍇',
      '🍓',
      '🫐',
      '🍒',
      '🍑',
      '🥭',
      '🍍',
      '🥥',
      '🥝',
      '🍅',
      '🍆',
      '🥑',
      '🥦',
      '🥬',
      '🥒',
      '🌶️',
      '🌽',
      '🥕',
      '🧄',
      '🧅',
      '🥔',
      '🍠',
      '🥐',
      '🥯',
      '🍞',
      '🥖',
      '🥨',
      '🧀',
      '🥚',
      '🍳',
      '🧈',
      '🥞',
      '🥓',
      '🥩',
      '🍗',
      '🍖',
      '🌭',
      '🍔',
      '🍟',
      '🍕',
      '🥪',
      '🥙',
      '🧆',
      '🌮',
      '🌯',
      '🥗',
      '🥘',
      '🥫',
      '🍝',
      '🍜',
      '🍲',
      '🍛',
      '🍣',
      '🍱',
      '🥟',
      '🦪',
      '🍤',
      '🍙',
      '🍚',
      '🍖',
      '🍗',
      '🥠',
      '🥮',
      '🍢',
      '🍡',
      '🍧',
      '🍨',
      '🍦',
      '🍰',
      '🎂',
      '🧁',
      '🍮',
      '🍭',
      '🍬',
      '🍫',
      '🍿',
      '🍩',
      '🍪',
      '🌰',
      '🍯',
      '☕',
      '🍵',
      '🍶',
      '🍾',
      '🍷',
      '🍸',
      '🍹',
      '🍺',
      '🍻',
      '🥂',
      '🥃',
      '🥤',
      '🧋',
    ],
  },
  {
    'icon': '⚽',
    'label': 'Sports',
    'emojis': [
      '⚽',
      '🏀',
      '🏈',
      '⚾',
      '🥎',
      '🎾',
      '🏐',
      '🏉',
      '🥏',
      '🎳',
      '🏓',
      '🏸',
      '🏒',
      '🏑',
      '🥊',
      '🥋',
      '🥅',
      '⛳',
      '⛸️',
      '🎣',
      '🎽',
      '🎿',
      '⛷️',
      '🏂',
      '🪂',
      '🛼',
      '🛹',
      '🛺',
      '🏇',
      '🏌️',
      '🏄',
      '🏊',
      '🤽',
      '🚣',
      '🧗',
      '🚴',
      '🚵',
      '🎯',
      '🪃',
      '🎮',
      '🎲',
      '♟️',
      '🏆',
      '🏅',
      '🥇',
      '🥈',
      '🥉',
      '🎖️',
    ],
  },
  {
    'icon': '🌍',
    'label': 'Travel',
    'emojis': [
      '✈️',
      '🚁',
      '🚂',
      '🚆',
      '🚇',
      '🚈',
      '🚉',
      '🚊',
      '🚝',
      '🚞',
      '🚋',
      '🚌',
      '🚎',
      '🚐',
      '🚑',
      '🚒',
      '🚓',
      '🚔',
      '🚕',
      '🚖',
      '🚗',
      '🚘',
      '🚙',
      '🚚',
      '🚛',
      '🚜',
      '🏎️',
      '🏍️',
      '🛵',
      '🦯',
      '🦽',
      '🦼',
      '🛺',
      '🚲',
      '🛴',
      '🛹',
      '🛼',
      '🚏',
      '⛽',
      '🚨',
      '🚥',
      '🚦',
      '🛑',
      '🚧',
      '⚓',
      '⛵',
      '🚤',
      '🛳️',
      '🛰️',
      '🚀',
      '🛸',
    ],
  },
  {
    'icon': '💡',
    'label': 'Objects',
    'emojis': [
      '⌚',
      '📱',
      '📲',
      '💻',
      '⌨️',
      '🖥️',
      '🖨️',
      '🖱️',
      '🖲️',
      '🕹️',
      '🗜️',
      '💽',
      '💾',
      '💿',
      '📀',
      '📧',
      '📨',
      '📩',
      '📤',
      '📥',
      '📦',
      '🏷️',
      '📪',
      '📫',
      '📬',
      '📭',
      '📮',
      '📯',
      '📜',
      '📃',
      '📄',
      '📑',
      '🧾',
      '📊',
      '📈',
      '📉',
      '📇',
      '📓',
      '📔',
      '📒',
      '📕',
      '📖',
      '📗',
      '📘',
      '📙',
      '📚',
      '📓',
      '📕',
      '📖',
      '📗',
      '📘',
      '📙',
      '📚',
      '📛',
      '🔖',
      '🧷',
      '🧷',
      '🧹',
      '🧺',
      '🧻',
      '🧼',
      '🧽',
      '🧾',
      '🧿',
      '💄',
      '💅',
      '💆',
      '💇',
      '🚪',
      '🛗',
      '🪜',
      '🪟',
      '🛏️',
      '🛋️',
      '🪑',
      '🚽',
      '🚿',
      '🛁',
      '🛀',
      '🧼',
    ],
  },
  {
    'icon': '🌟',
    'label': 'Nature',
    'emojis': [
      '🌸',
      '🌼',
      '🌻',
      '🌺',
      '🌷',
      '🌹',
      '🥀',
      '🌱',
      '🌲',
      '🌳',
      '🌴',
      '🌵',
      '🌾',
      '🌿',
      '☘️',
      '🍀',
      '🍁',
      '🍂',
      '🍃',
      '🍇',
      '🍈',
      '🍉',
      '🍊',
      '🍋',
      '🍌',
      '🍍',
      '🥭',
      '🍎',
      '🍏',
      '🍐',
      '🍑',
      '🍒',
      '🍓',
      '🫐',
      '🥝',
      '🍅',
      '🍆',
      '🥑',
      '🥦',
      '🌽',
      '🌶️',
      '🌈',
      '⛅',
      '☁️',
      '⛈️',
      '🌤️',
      '🌥️',
      '🌦️',
      '🌧️',
      '☔',
      '⚡',
      '❄️',
      '☃️',
      '⛄',
      '🌬️',
      '💨',
      '💧',
      '💦',
      '☔',
      '🌊',
      '🌫️',
    ],
  },
  {
    'icon': '🎉',
    'label': 'Celebration',
    'emojis': [
      '🎉',
      '🎊',
      '🎈',
      '🎀',
      '🎁',
      '🎇',
      '🎆',
      '🧨',
      '✨',
      '⭐',
      '🌟',
      '🌠',
      '🌌',
      '🎃',
      '🎄',
      '🎆',
      '🎇',
      '✨',
      '🎈',
      '🎉',
      '🎊',
      '🎋',
      '🎍',
      '🎎',
      '🏮',
      '🎏',
      '🎐',
      '🎑',
      '🧧',
      '🎀',
      '🎁',
      '🎗️',
      '🎟️',
      '🎫',
      '🎖️',
      '🏆',
      '🏅',
      '⭐',
      '💫',
      '⚡',
      '🔥',
      '💥',
      '🌟',
      '⭐',
      '✨',
      '💫',
      '🌠',
    ],
  },
  {
    'icon': '💯',
    'label': 'Symbols',
    'emojis': [
      '✅',
      '❌',
      '⭕',
      '💯',
      '❗',
      '❓',
      '⚠️',
      '♻️',
      '➕',
      '➖',
      '➗',
      '✖️',
      '🔥',
      '✨',
      '⚡',
      '💥',
      '🎉',
      '🎊',
      '🎈',
      '🎁',
      '🔔',
      '🔕',
      '🎵',
      '🎶',
      '🔑',
      '🗝',
      '💡',
      '🔒',
      '🔓',
      '🆚',
      '🔱',
      '🔂',
      '🔁',
      '🔄',
      '🔃',
      '⏪',
      '⏫',
      '⏬',
      '⏭️',
      '⏮️',
      '⏸️',
      '⏹️',
      '⏺️',
      '⏻️',
      '📴',
      '📳',
      '🔀',
      '🔈',
      '🔉',
      '🔊',
      '🔇',
      '📢',
      '📣',
      '📯',
      '🔔',
      '🔕',
      '📻',
      '📺',
      '📷',
      '📸',
      '🎥',
      '🎬',
      '📽️',
      '🎞️',
      '📞',
      '☎️',
      '📟',
      '📠',
    ],
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// CHAT SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.pairingId,
    required this.threadId,
  });

  final String pairingId;
  final String? threadId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final SupabaseService _sb;
  late final TextEditingController _composerCtrl;
  late final FocusNode _composerFocus;
  late final ScrollController _scrollCtrl;
  late final AnimationController _glowCtrl;

  bool _loading = true;
  String? _error;
  bool _sending = false;
  bool _hasText = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 30;

  // Chat Data
  Pairing? _pairing;
  UserProfile? _partner;
  String _partnerName = 'Partner';
  List<Message> _messages = [];

  // Message State
  Message? _editingMessage;
  Message? _replyTarget;
  List<Message> _pinnedMessages = [];
  late ValueNotifier<bool> _showScrollToBottomNotifier;

  // Reactions stored locally (key: messageId, value: {emoji: count})
  final Map<String, Map<String, int>> _reactions = {};
  final Map<String, String?> _myReactions = {};

  // Presence
  late SharedPreferences _prefs;
  bool _partnerOnline = false;
  DateTime? _partnerLastSeen;

  // Search
  bool _isSearchActive = false;
  String _searchQuery = '';
  int _searchResultIndex = 0;
  List<String> _searchResultIds = [];
  final TextEditingController _searchCtrl = TextEditingController();

  // Subscriptions
  StreamSubscription<List<Message>>? _messageSub;
  StreamSubscription<List<UserProfile>>? _profileSub;
  StreamSubscription<UserProfile>? _presenceSub;
  StreamSubscription? _typingStreamSub;
  String? _typingPairingId;
  StreamSubscription<Map<String, dynamic>>? _chatPresenceSub;
  StreamSubscription<Map<String, List<MessageReaction>>>? _allReactionsSub;
  final Set<String> _reactionInFlight = {};
  Timer? _selfTypingHeartbeat;
  Timer? _partnerTypingTimer;
  Timer? _inactivityTimer;
  UserProfile? _myProfile;

  final Set<String> _starredMessages = {};

  bool _amITyping = false;
  bool _isPartnerTyping = false;
  bool _isPartnerInChat = false;
  Timer? _presenceTimer;
  Timer? _presenceDebounceTimer;
  String? _highlightedMessageId;
  Timer? _highlightTimer;
  final Map<String, GlobalKey> _messageKeys = {};
  final Map<String, GlobalKey> _bubbleKeys = {};

  // Voice recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  String? _recordingDuration;
  final GlobalKey _composerTextFieldKey = GlobalKey();

  // ─────────────────────────────────────────────────────────────────────────
  // EMOJI PICKER STATE — managed here, rendered via Overlay so it floats
  // above the ListView and is never clipped by it.
  // ─────────────────────────────────────────────────────────────────────────
  String? _openQuickPickerId;
  // ignore: unused_field
  String? _openFullPickerId;

  // Composer emoji picker state — ValueNotifier so only the panel rebuilds,
  // not the entire chat screen / composer bar.
  final ValueNotifier<bool> _showComposerEmoji = ValueNotifier(false);
  final ValueNotifier<int> _composerEmojiCat = ValueNotifier(0);
  PageController? _composerEmojiPageCtrl;
  int _fullPickerCatIndex = 0;
  String _emojiSearchQ = '';
  final TextEditingController _emojiSearchCtrl = TextEditingController();

  // The single overlay entry that hosts whichever picker is open.
  OverlayEntry? _pickerOverlayEntry;

  // ─────────────────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sb = SupabaseService();
    _composerCtrl = TextEditingController();
    _composerFocus = FocusNode();
    _scrollCtrl = ScrollController();
    _showScrollToBottomNotifier = ValueNotifier(false);
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _composerCtrl.addListener(_onComposerChanged);
    _composerFocus.addListener(() {
      if (_composerFocus.hasFocus && _showComposerEmoji.value) {
        _showComposerEmoji.value = false;
      }
    });
    _scrollCtrl.addListener(_onScroll);
    _initializeChatAsync();
  }

  Future<void> _initializeChatAsync() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      String? effectivePairingId = widget.pairingId.isNotEmpty
          ? widget.pairingId
          : null;

      final prefs = _sb.prefsSync;
      if (prefs != null && effectivePairingId == null) {
        final cachedPairingStr = prefs.getString('cache_active_pairing');
        if (cachedPairingStr != null) {
          try {
            final cachedPairing = Pairing.fromJson(
              jsonDecode(cachedPairingStr),
            );
            effectivePairingId = cachedPairing.id;
            if (mounted) {
              setState(() => _pairing = cachedPairing);
              _initTypingListener(effectivePairingId);
            }
          } catch (_) {}
        }
      }

      if (effectivePairingId != null) {
        _subscribeToMessages(effectivePairingId);
        unawaited(_sb.markAllMessagesAsRead(effectivePairingId));
      }

      final pairing = await _resolvePairing();
      if (pairing == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Ensure this device's E2EE public key is published so messages can be
      // encrypted for the partner (no-op once already published).
      unawaited(EncryptionService.instance.ensureKeyPairAndUpload());

      if (effectivePairingId != pairing.id) {
        _subscribeToMessages(pairing.id);
      }

      final me = await _sb.getMyProfile();
      final partner = await _sb.getPartnerProfile(pairing.id);

      if (!mounted) return;

      setState(() {
        _pairing = pairing;
        _myProfile = me;
        _partner = partner;
        _partnerName =
            me?.preferences['partner_nickname'] ??
            partner?.displayName ??
            'Partner';
        _loading = false;
      });

      if (_pairing != null) {
        _initTypingListener(_pairing!.id);
        _initChatPresence(_pairing!.id);
        final starred = _prefs.getStringList(
          'starred_messages_${_pairing!.id}',
        );
        if (starred != null) setState(() => _starredMessages.addAll(starred));
        _loadReactions();
        _initReactionListener();
      }
      _watchPartnerPresence();
    } catch (e) {
      debugPrint('[Chat/Init] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadReactions() {
    final raw = _prefs.getString('reactions_${_pairing?.id}');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((msgId, val) {
          _reactions[msgId] = Map<String, int>.from(val as Map);
        });
      } catch (_) {}
    }
    final myRaw = _prefs.getString('my_reactions_${_pairing?.id}');
    if (myRaw != null) {
      try {
        final decoded = jsonDecode(myRaw) as Map<String, dynamic>;
        decoded.forEach((msgId, emoji) {
          _myReactions[msgId] = emoji as String?;
        });
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _persistReactions() async {
    await _prefs.setString('reactions_${_pairing?.id}', jsonEncode(_reactions));
    await _prefs.setString(
      'my_reactions_${_pairing?.id}',
      jsonEncode(_myReactions),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUBSCRIPTIONS
  // ─────────────────────────────────────────────────────────────────────────

  void _subscribeToMessages(String pairingId) {
    _messageSub?.cancel();
    _messageSub = _sb.watchMessages(pairingId).listen((messages) {
      if (!mounted) return;
      setState(() {
        final confirmedIds = messages.map((m) => m.id).toSet();
        final confirmedTempIds = messages
            .map((m) => m.metadata['client_temp_id']?.toString())
            .whereType<String>()
            .toSet();
        // Pending (optimistic) messages must render at the bottom of the
        // thread, i.e. first in this newest-first list. Appending them after
        // the server list previously placed them at the TOP.
        final pending = _messages.where(
          (m) =>
              m.metadata['pending'] == true &&
              !confirmedIds.contains(m.id),
        );
        _messages = [
          ...pending,
          ...messages,
        ].where((m) {
          if (m.metadata['pending'] != true) {
            return true;
          }
          return !confirmedTempIds.contains(m.id);
        }).toList();
        _loading = false;
        _error = null;
        _pinnedMessages = messages.where((m) {
          final until = m.metadata['pinned_until'];
          if (until == null) return false;
          final expiry = DateTime.tryParse(until.toString());
          if (expiry == null) return false;
          return expiry.isAfter(DateTime.now());
        }).toList();
        _pinnedMessages.sort((a, b) {
          final aAt = a.metadata['pinned_at'] ?? '';
          final bAt = b.metadata['pinned_at'] ?? '';
          return aAt.toString().compareTo(bAt.toString());
        });
      });
      _pruneMessageKeys();
      // Mark unread incoming messages as read only when there actually ARE
      // unread ones — previously this fired on every stream event (including
      // the echo of the read-marking UPDATE itself), causing write churn.
      final hasUnreadIncoming = messages.any(
        (m) => !m.isRead && m.senderId != _sb.currentUserId,
      );
      if (hasUnreadIncoming && _pairing != null) {
        _sb.markAllMessagesAsRead(_pairing!.id).ignore();
      }
    }, onError: (e) => debugPrint('[Lovit/Chat] Message stream error: $e'));
  }

  void _pruneMessageKeys() {
    final activeIds = _messages.map((m) => m.id).toSet();
    _messageKeys.removeWhere((id, _) => !activeIds.contains(id));
    _bubbleKeys.removeWhere((id, _) => !activeIds.contains(id));
  }

  /// Single subscription for all reactions in the current chat. Previously a
  /// per-message watchReactions() stream was opened for every message (N+1).
  void _initReactionListener() {
    _allReactionsSub?.cancel();
    _allReactionsSub = _sb.watchAllReactions().listen((grouped) {
      if (!mounted) return;
      setState(() {
        _reactions.clear();
        _myReactions.clear();
        grouped.forEach((id, reactions) {
          final counts = <String, int>{};
          String? mine;
          for (final reaction in reactions) {
            counts[reaction.emoji] = (counts[reaction.emoji] ?? 0) + 1;
            if (reaction.userId == _sb.currentUserId) {
              mine = reaction.emoji;
            }
          }
          if (counts.isNotEmpty) _reactions[id] = counts;
          if (mine != null) _myReactions[id] = mine;
        });
      });
      _persistReactions().ignore();
    }, onError: (e) => debugPrint('[Lovit/Chat] Reactions stream error: $e'));
  }

  void _initTypingListener(String pairingId) {
    if (_typingStreamSub != null && _typingPairingId == pairingId) return;
    // The pairing id can change between the cached pairing resolution and the
    // authoritative one — always rebind to the latest id instead of keeping
    // a stale channel.
    _typingStreamSub?.cancel();
    if (_typingPairingId != null) {
      _sb.releaseTypingChannel(_typingPairingId!);
    }
    _typingPairingId = pairingId;
    _typingStreamSub = _sb.watchTyping(pairingId).listen((payload) {
      if (!mounted) return;
      final userId = payload['user_id'];
      final isTyping = payload['is_typing'] as bool;
      if (userId != _sb.currentUserId) {
        setState(() => _isPartnerTyping = isTyping);
        _partnerTypingTimer?.cancel();
        if (isTyping) {
          _partnerTypingTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) setState(() => _isPartnerTyping = false);
          });
        }
      }
    });
  }

  void _initChatPresence(String pairingId) {
    _chatPresenceSub?.cancel();
    _chatPresenceSub = _sb.watchChatPresence(pairingId).listen((payload) {
      if (!mounted) return;
      final userId = payload['user_id'] as String?;
      if (userId == null || userId == _sb.currentUserId) return;
      final isInChat = payload['is_in_chat'] as bool? ?? false;
      if (_isPartnerInChat != isInChat) {
        setState(() => _isPartnerInChat = isInChat);
      }
    });
    _broadcastMyChatPresence(true);
    NotificationService.instance.setActiveChat(
      pairingId: pairingId,
      threadId: widget.threadId,
    );
  }

  void _broadcastMyChatPresence(bool isInChat) {
    final pairing = _pairing;
    if (pairing == null) return;
    _sb.broadcastChatPresence(
      pairing.id,
      isInChat: isInChat,
      threadId: widget.threadId,
    );
  }

  bool get _shouldSuppressMessagePush => _isPartnerInChat;

  String _buildCallRoomName({required bool isVideo}) {
    // Include a cryptographically random token so the Jitsi room cannot be
    // guessed from the predictable pairing id.
    final rng = Random.secure();
    final nonce =
        List.generate(6, (_) => rng.nextInt(36).toRadixString(36)).join();
    final base =
        '${_pairing?.id ?? widget.pairingId}_${widget.threadId ?? 'main'}_${nonce}_${isVideo ? 'video' : 'voice'}';
    final sanitized = base
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .toLowerCase();
    return 'lovit_$sanitized';
  }

  String _myCallDisplayName() {
    final displayName = _myProfile?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return 'Lovit User';
  }

  Future<void> _startCall({required bool isVideo}) async {
    if (_pairing == null) {
      _showIGToast('Chat is still loading');
      return;
    }

    final roomName = _buildCallRoomName(isVideo: isVideo);
    // Avatars are now stored as private storage paths; resolve a short-lived
    // signed URL so the call UI can render them for the call's duration.
    final myAvatar = _myProfile?.avatarUrl ?? '';
    final partnerAvatar = _partner?.avatarUrl ?? '';
    final myAvatarUrl =
        myAvatar.isEmpty ? '' : await _sb.secureMediaUrl(myAvatar);
    final partnerAvatarUrl = partnerAvatar.isEmpty
        ? ''
        : await _sb.secureMediaUrl(partnerAvatar);

    final joined = await CallService.instance.startOutgoingCall(
      roomName: roomName,
      isVideo: isVideo,
      displayName: _myCallDisplayName(),
      avatarUrl: myAvatarUrl.isEmpty ? null : myAvatarUrl,
    );

    if (!joined) {
      if (mounted) {
        _showIGToast('Could not start ${isVideo ? 'video' : 'voice'} call');
      }
      return;
    }

    final partnerId = _partner?.id;
    if (partnerId != null && partnerId.isNotEmpty) {
      final callerName = _myCallDisplayName();
      unawaited(
        _sb.sendPushNotification(
          toUserId: partnerId,
          type: isVideo ? CallService.videoCallType : CallService.voiceCallType,
          title: isVideo
              ? 'Video call from $callerName'
              : 'Voice call from $callerName',
          body: 'Tap to join now',
          data: {
            'pairing_id': _pairing!.id,
            'room_name': roomName,
            'caller_name': callerName,
            'caller_avatar_url': myAvatarUrl,
            'recipient_name': _partner?.displayName ?? '',
            'recipient_avatar_url': partnerAvatarUrl,
          },
        ),
      );
    }

    if (mounted) {
      _showIGToast('${isVideo ? 'Video' : 'Voice'} call started');
    }
  }

  void _maybeSendMessagePush({required String title, required String body}) {
    if (_partner?.id == null) return;
    if (_shouldSuppressMessagePush) {
      debugPrint(
        '[Chat/Push] Suppressed message push because partner is in chat',
      );
      return;
    }
    unawaited(
      _sb.sendPushNotification(
        toUserId: _partner!.id,
        type: 'message',
        title: title,
        body: body,
        data: {'pairing_id': _pairing!.id},
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _broadcastMyChatPresence(true);
      final pairing = _pairing;
      if (pairing != null) {
        NotificationService.instance.setActiveChat(
          pairingId: pairing.id,
          threadId: widget.threadId,
        );
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _broadcastMyChatPresence(false);
      NotificationService.instance.clearActiveChat(
        pairingId: _pairing?.id,
        threadId: widget.threadId,
      );
    }
  }

  void _watchPartnerPresence() {
    if (_partner == null || _partner!.id.isEmpty) return;
    _presenceTimer?.cancel();
    _presenceDebounceTimer?.cancel();
    _presenceSub?.cancel();
    _presenceSub = _sb.watchPartnerPresence(_partner!.id).listen((profile) {
      if (!mounted) return;
      // Debounce rapid presence changes (300ms) to avoid UI flicker
      _presenceDebounceTimer?.cancel();
      _presenceDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _partner = profile;
            _partnerLastSeen = profile.lastSeen ?? profile.updatedAt;
            _partnerOnline = profile.isOnline;
          });
        }
      });
    }, onError: (e) => debugPrint('[Chat/Presence] $e'));
  }

  Future<Pairing?> _resolvePairing() async {
    if (widget.pairingId.isNotEmpty) {
      return await _sb.getPairing(widget.pairingId);
    }
    return await _sb.getActivePairing();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMPOSER
  // ─────────────────────────────────────────────────────────────────────────

  void _onComposerChanged() {
    final hasText = _composerCtrl.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
    _sendTypingStatus(hasText);
    _inactivityTimer?.cancel();
    if (hasText) {
      _inactivityTimer = Timer(const Duration(seconds: 2), () {
        if (_amITyping) _sendTypingStatus(false);
      });
    }
  }

  void _sendTypingStatus(bool isTyping) {
    if (!isTyping) {
      _selfTypingHeartbeat?.cancel();
      if (_amITyping) {
        _amITyping = false;
        _sendTypingBroadcast(false);
      }
      return;
    }
    if (!_amITyping) {
      _amITyping = true;
      _sendTypingBroadcast(true);
      _startTypingHeartbeat();
    }
  }

  void _sendTypingBroadcast(bool isTyping) {
    if (_pairing == null) return;
    _sb.sendTypingStatus(_pairing!.id, isTyping);
  }

  void _startTypingHeartbeat() {
    _selfTypingHeartbeat?.cancel();
    _selfTypingHeartbeat = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_amITyping && mounted && _composerCtrl.text.trim().isNotEmpty) {
        _sendTypingBroadcast(true);
      } else {
        timer.cancel();
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCROLL
  // ─────────────────────────────────────────────────────────────────────────

  void _onScroll() {
    final show = _scrollCtrl.hasClients && _scrollCtrl.offset > 300;
    if (show != _showScrollToBottomNotifier.value) {
      _showScrollToBottomNotifier.value = show;
    }
    if (_scrollCtrl.hasClients &&
        _scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_pairing == null || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final olderMessages = await _sb.getMessages(
        _pairing!.id,
        limit: _pageSize,
        offset: _messages.length,
      );
      if (mounted) {
        setState(() {
          if (olderMessages.length < _pageSize) _hasMore = false;
          final existingIds = _messages.map((m) => m.id).toSet();
          final newUnique = olderMessages
              .where((m) => !existingIds.contains(m.id))
              .toList();
          _messages.addAll(newUnique);
          _loadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('[Chat/LoadMore] $e');
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _scrollToMessage(String messageId) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    _highlightTimer?.cancel();
    setState(() => _highlightedMessageId = messageId);

    final key = _messageKeys[messageId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutQuart,
        alignment: 0.5,
      );
    } else {
      // Estimate target offset: index 0 is at the bottom (0.0), index length-1 is at the top (maxScrollExtent)
      final ratio = index / max(1, _messages.length - 1);
      final targetOffset = ratio * _scrollCtrl.position.maxScrollExtent;

      _scrollCtrl
          .animateTo(
            targetOffset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          )
          .then((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final k = _messageKeys[messageId];
              if (k?.currentContext != null) {
                Scrollable.ensureVisible(
                  k!.currentContext!,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutQuart,
                  alignment: 0.5,
                );
              }
            });
          });
    }

    _highlightTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _highlightedMessageId = null);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REACTIONS & OVERLAY EMOJI PICKER
  // ─────────────────────────────────────────────────────────────────────────

  void _toggleReaction(String msgId, String emoji) async {
    if (_reactionInFlight.contains(msgId)) return;
    _reactionInFlight.add(msgId);
    try {
      await _doToggleReaction(msgId, emoji);
    } finally {
      _reactionInFlight.remove(msgId);
    }
  }

  Future<void> _doToggleReaction(String msgId, String emoji) async {
    final previousCounts = _reactions[msgId] == null
        ? null
        : Map<String, int>.from(_reactions[msgId]!);
    final previousMine = _myReactions[msgId];
    final matchingMessages = _messages.where((m) => m.id == msgId);
    if (matchingMessages.isEmpty) {
      return;
    }

    setState(() {
      _reactions.putIfAbsent(msgId, () => {});
      final prev = previousMine;
      if (prev == emoji) {
        _reactions[msgId]![emoji] = max(
          0,
          (_reactions[msgId]![emoji] ?? 1) - 1,
        );
        if (_reactions[msgId]![emoji] == 0) _reactions[msgId]!.remove(emoji);
        _myReactions.remove(msgId);
        _showIGToast('Reaction removed');
      } else {
        if (prev != null) {
          _reactions[msgId]![prev] = max(
            0,
            (_reactions[msgId]![prev] ?? 1) - 1,
          );
          if (_reactions[msgId]![prev] == 0) _reactions[msgId]!.remove(prev);
        }
        _reactions[msgId]![emoji] = (_reactions[msgId]![emoji] ?? 0) + 1;
        _myReactions[msgId] = emoji;
        _showIGToast('Reacted with $emoji');
        // Notify the message sender if it was their message
        final msg = _messages.firstWhere(
          (m) => m.id == msgId,
          orElse: () => _messages.first,
        );
        if (msg.senderId != _sb.currentUserId && _partner?.id != null) {
          final senderName =
              _partner?.preferences['partner_nickname'] ??
              _myProfile?.displayName ??
              'Someone';
          unawaited(
            _sb.sendPushNotification(
              toUserId: _partner!.id,
              type: 'reaction',
              title: '💜 $senderName reacted',
              body: '$emoji to your message',
            ),
          );
        }
      }
    });
    _closeAllPickers();
    _persistReactions().ignore();
    HapticFeedback.lightImpact();

    try {
      if (previousMine == emoji) {
        await _sb.removeReaction(messageId: msgId, emoji: emoji);
      } else {
        if (previousMine != null && previousMine != emoji) {
          await _sb.removeReaction(messageId: msgId, emoji: previousMine);
        }
        await _sb.addReaction(messageId: msgId, emoji: emoji);
      }
    } catch (e) {
      debugPrint('[Chat/Reaction] $e');
      if (!mounted) {
        return;
      }
      setState(() {
        if (previousCounts == null || previousCounts.isEmpty) {
          _reactions.remove(msgId);
        } else {
          _reactions[msgId] = previousCounts;
        }
        if (previousMine == null) {
          _myReactions.remove(msgId);
        } else {
          _myReactions[msgId] = previousMine;
        }
      });
      _persistReactions().ignore();
      _showIGToast('Failed to sync reaction');
    }
  }

  /// Remove the overlay and clear picker state.
  void _closeAllPickers() {
    _pickerOverlayEntry?.remove();
    _pickerOverlayEntry = null;
    if (mounted) {
      setState(() {
        _openQuickPickerId = null;
        _openFullPickerId = null;
        _emojiSearchQ = '';
        _emojiSearchCtrl.clear();
        _fullPickerCatIndex = 0;
      });
    }
  }

  /// Show the quick-emoji bar in an Overlay anchored to the tapped bubble.
  void _toggleQuickPicker(String msgId, GlobalKey bubbleKey, bool isSent) {
    if (_openQuickPickerId == msgId) {
      _closeAllPickers();
      return;
    }
    _closeAllPickers();

    final ctx = bubbleKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;

    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    setState(() => _openQuickPickerId = msgId);

    // Extract custom emoji if user has reacted with something not in default 6
    final userReaction = _myReactions[msgId];
    final customEmoji =
        userReaction != null && !_kQuickEmojis.contains(userReaction)
        ? userReaction
        : null;

    _pickerOverlayEntry = OverlayEntry(
      builder: (_) => _OverlayQuickPicker(
        msgId: msgId,
        isSent: isSent,
        bubbleTopLeft: pos,
        bubbleSize: size,
        myReaction: _myReactions[msgId],
        customEmoji: customEmoji,
        onReaction: (emoji) => _toggleReaction(msgId, emoji),
        onMoreEmoji: () => _openFullPickerOverlay(msgId, pos, size, isSent),
        onDismiss: _closeAllPickers,
      ),
    );
    Overlay.of(context).insert(_pickerOverlayEntry!);
  }

  /// Replace the quick picker with the full emoji keyboard in the Overlay.
  ///
  /// FIX: Instead of wrapping in StatefulBuilder and calling markNeedsBuild()
  /// (which doesn't propagate new field values from _ChatScreenState into the
  /// already-captured closure), we use a local recursive `buildOverlay()`
  /// function that replaces the entire OverlayEntry whenever category or search
  /// state changes. This guarantees the new OverlayEntry's builder closure
  /// captures the latest values of _fullPickerCatIndex and _emojiSearchQ.
  void _openFullPickerOverlay(
    String msgId,
    Offset pos,
    Size size,
    bool isSent,
  ) {
    _pickerOverlayEntry?.remove();
    _pickerOverlayEntry = null;

    // Reset state directly — no setState needed since we're about to insert
    // a fresh overlay entry that reads these fields at build time.
    _openQuickPickerId = null;
    _openFullPickerId = msgId;
    _emojiSearchQ = '';
    _emojiSearchCtrl.clear();
    _fullPickerCatIndex = 0;

    void buildOverlay() {
      _pickerOverlayEntry?.remove();

      _pickerOverlayEntry = OverlayEntry(
        builder: (_) => _OverlayFullPicker(
          msgId: msgId,
          isSent: isSent,
          bubbleTopLeft: pos,
          bubbleSize: size,
          myReaction: _myReactions[msgId],
          // These are read at the moment buildOverlay() is called, so they are
          // always up-to-date when a new entry is inserted.
          catIndex: _fullPickerCatIndex,
          searchQ: _emojiSearchQ,
          searchCtrl: _emojiSearchCtrl,
          onReaction: (emoji) => _toggleReaction(msgId, emoji),
          onDismiss: _closeAllPickers,
          onCatChange: (i) {
            // Just persist the index so it's remembered if picker is re-opened.
            // The StatefulWidget manages its own PageController — no rebuild needed.
            _fullPickerCatIndex = i;
          },
          onSearch: (q) {
            // Update search query and rebuild overlay with new search results
            _emojiSearchQ = q;
            buildOverlay();
          },
        ),
      );

      if (mounted) Overlay.of(context).insert(_pickerOverlayEntry!);
    }

    buildOverlay();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MESSAGE ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  void _startEditingMessage(Message msg) {
    if (msg.senderId != _sb.currentUserId) {
      _showIGToast('Can only edit your own messages');
      return;
    }
    setState(() {
      _editingMessage = msg;
      _composerCtrl.text = msg.content ?? '';
    });
    _composerFocus.requestFocus();
  }

  Future<void> _saveMessageEdit() async {
    if (_editingMessage == null) return;
    final content = _composerCtrl.text.trim();
    if (content.isEmpty) {
      _showIGToast('Message cannot be empty');
      return;
    }
    try {
      setState(() => _sending = true);
      await _sb.editMessage(
        messageId: _editingMessage!.id,
        newContent: content,
      );
      if (!mounted) return;
      _showIGToast('Message edited');
      _cancelEditingMessage();
    } catch (e) {
      if (mounted) _showIGToast('Error editing message');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _cancelEditingMessage() {
    setState(() {
      _editingMessage = null;
      _composerCtrl.clear();
    });
  }

  Future<void> _sendMessage() async {
    if (_pairing == null || _sending) return;
    if (_editingMessage != null) {
      await _saveMessageEdit();
      return;
    }
    final content = _composerCtrl.text.trim();
    if (content.isEmpty) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = Message(
      id: tempId,
      pairingId: _pairing!.id,
      senderId: _sb.currentUserId!,
      content: content,
      messageType: 'text',
      replyToId: _replyTarget?.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: {'pending': true, 'client_temp_id': tempId},
    );

    setState(() {
      _sending = true;
      _messages = [tempMsg, ..._messages];
      _composerCtrl.clear();
      _replyTarget = null;
      _sendTypingStatus(false);
    });
    _scrollToBottom();

    try {
      await _sb.sendMessage(
        pairingId: _pairing!.id,
        content: content,
        messageType: 'text',
        replyToId: tempMsg.replyToId,
        metadata: {'client_temp_id': tempId},
      );
      // Push notification to partner (fires even if app is killed/backgrounded).
      // Body intentionally omits the message text: content is end-to-end
      // encrypted, and the push channel must not leak it as plaintext.
      if (_partner?.id != null) {
        final senderName =
            _partner?.preferences['partner_nickname'] ??
            _myProfile?.displayName ??
            'Someone';
        _maybeSendMessagePush(title: '💬 $senderName', body: 'Sent you a message');
      }
    } catch (e) {
      debugPrint('[Chat/Send] $e');
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == tempId);
          _composerCtrl.text = content;
        });
        _showIGToast('Failed to send. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _unsendMessage(Message msg) async {
    try {
      await _sb.deleteMessage(msg.id);
      _showIGToast('Message unsent');
    } catch (e) {
      _showIGToast('Failed to unsend message');
    }
  }

  // ignore: unused_element
  Future<void> _deleteMessage(Message msg, {bool everyone = false}) async {
    try {
      await _sb.deleteMessage(msg.id);
      _showIGToast(
        everyone ? 'Message deleted for everyone' : 'Message deleted',
      );
    } catch (e) {
      _showIGToast('Error deleting message');
    }
  }

  void _pinMessage(Message msg, int days) {
    if (_pinnedMessages.length >= 3) {
      _showPinLimitConfirm(msg, days);
    } else {
      _executePin(msg, days);
    }
  }

  void _showPinLimitConfirm(Message newMsg, int days) {
    showDialog(
      context: context,
      builder: (context) => _IGAlertDialog(
        title: 'Pin limit reached',
        content:
            'You can only pin up to 3 messages. This will remove the oldest pin.',
        actions: [
          _IGDialogAction(label: 'Cancel', onTap: () => Navigator.pop(context)),
          _IGDialogAction(
            label: 'Continue',
            isPrimary: true,
            onTap: () {
              Navigator.pop(context);
              if (_pinnedMessages.isNotEmpty) {
                _unpinMessage(_pinnedMessages.first.id);
              }
              _executePin(newMsg, days);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _executePin(Message msg, int days) async {
    try {
      final until = DateTime.now().toUtc().add(Duration(days: days));
      await _sb.updateMessageMetadata(msg.id, {
        'pinned_until': until.toIso8601String(),
        'pinned_by': _sb.currentUserId,
        'pinned_at': DateTime.now().toUtc().toIso8601String(),
      });
      _showIGToast('Message pinned for $days day${days > 1 ? 's' : ''}');
      // Notify partner about the pin. Body avoids echoing the (encrypted)
      // message content over the push channel.
      if (_partner?.id != null) {
        unawaited(
          _sb.sendPushNotification(
            toUserId: _partner!.id,
            type: 'pin',
            title: '📌 Message pinned',
            body: 'A message was pinned',
            data: {'pairing_id': _pairing?.id ?? ''},
          ),
        );
      }
    } catch (e) {
      _showIGToast('Error pinning message');
    }
  }

  Future<void> _unpinMessage(String messageId) async {
    try {
      await _sb.updateMessageMetadata(messageId, {
        'pinned_until': null,
        'pinned_by': null,
        'pinned_at': null,
      });
      _showIGToast('Message unpinned');
    } catch (e) {
      _showIGToast('Error unpinning message');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LONG-PRESS ACTION SHEET
  // ─────────────────────────────────────────────────────────────────────────

  void _openMessageActions(Message msg) {
    _closeAllPickers();
    final isMe = msg.senderId == _sb.currentUserId;
    final isPinned = _pinnedMessages.any((pm) => pm.id == msg.id);

    final isPoll =
        msg.messageType == 'poll' ||
        (msg.messageType == 'text' && msg.metadata['is_poll'] == true);

    final canEdit =
        isMe &&
        msg.messageType == 'text' &&
        !isPoll &&
        DateTime.now().toUtc().difference(msg.createdAt.toUtc()).inMinutes < 2;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _IGActionSheet(
        message: msg,
        isMe: isMe,
        isPinned: isPinned,
        canEdit: canEdit,
        myReaction: _myReactions[msg.id],
        partnerName: _partnerName,
        currentUserId: _sb.currentUserId ?? '',
        onReaction: (emoji) {
          Navigator.pop(context);
          _toggleReaction(msg.id, emoji);
        },
        onReply: () {
          Navigator.pop(context);
          setState(() => _replyTarget = msg);
          Future.delayed(const Duration(milliseconds: 80), () {
            if (mounted) _composerFocus.requestFocus();
          });
        },
        onCopy: () {
          Clipboard.setData(ClipboardData(text: msg.content ?? ''));
          Navigator.pop(context);
          _showIGToast('Copied');
        },
        onPin: () {
          Navigator.pop(context);
          if (isPinned) {
            _unpinMessage(msg.id);
          } else {
            _showPinDurationDialog(msg);
          }
        },
        onEdit: canEdit
            ? () {
                _startEditingMessage(msg);
                Navigator.pop(context);
              }
            : null,
        onUnsend: isMe
            ? () {
                Navigator.pop(context);
                _showUnsendConfirmDialog(msg);
              }
            : null,
      ),
    );
  }

  void _showUnsendConfirmDialog(Message msg) {
    showDialog(
      context: context,
      builder: (context) => _IGAlertDialog(
        title: 'Unsend message?',
        content: 'This message will be deleted for everyone.',
        actions: [
          _IGDialogAction(label: 'Cancel', onTap: () => Navigator.pop(context)),
          _IGDialogAction(
            label: 'Unsend',
            isDestructive: true,
            onTap: () {
              Navigator.pop(context);
              _unsendMessage(msg);
            },
          ),
        ],
      ),
    );
  }

  void _showPinDurationDialog(Message msg) {
    int selectedDays = 7;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _IGAlertDialog(
          title: 'How long should the pin last?',
          content: null,
          customContent: Column(
            mainAxisSize: MainAxisSize.min,
            children: [1, 7, 30].map((days) {
              final label = days == 1 ? '24 hours' : '$days days';
              return RadioListTile<int>(
                title: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: _IG.fontSizeMd,
                  ),
                ),
                value: days,
                // ignore: deprecated_member_use
                groupValue: selectedDays,
                activeColor: _IG.blue,
                // ignore: deprecated_member_use
                onChanged: (v) => setDialogState(() => selectedDays = v!),
              );
            }).toList(),
          ),
          actions: [
            _IGDialogAction(
              label: 'Cancel',
              onTap: () => Navigator.pop(context),
            ),
            _IGDialogAction(
              label: 'Pin',
              isPrimary: true,
              onTap: () {
                Navigator.pop(context);
                _pinMessage(msg, selectedDays);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOAST
  // ─────────────────────────────────────────────────────────────────────────

  OverlayEntry? _toastEntry;
  void _showIGToast(String message) {
    if (!mounted) return;

    try {
      _toastEntry?.remove();
      _toastEntry = null;
    } catch (_) {}

    final entry = OverlayEntry(builder: (_) => _IGToast(message: message));
    _toastEntry = entry;

    if (mounted) {
      Overlay.of(context).insert(entry);
      // Capture the entry so a later toast's timer can't remove this one.
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted && _toastEntry == entry) {
          try {
            entry.remove();
            _toastEntry = null;
          } catch (_) {}
        }
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MEDIA
  // ─────────────────────────────────────────────────────────────────────────

  // ignore: unused_element
  Future<void> _shareLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showIGToast('Location services disabled');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showIGToast('Location denied');
          return;
        }
      }
      final position = await Geolocator.getCurrentPosition();
      await _sb.sendMessage(
        pairingId: _pairing!.id,
        messageType: 'location',
        content: 'Shared a location',
        metadata: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      );
      _scrollToBottom();
    } catch (e) {
      _showIGToast('Error sharing location');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/${const Uuid().v4()}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        if (!mounted) return;
        setState(() {
          _isRecording = true;
          _recordingStartTime = DateTime.now();
          _recordingDuration = '0:00';
        });
        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          final diff = DateTime.now().difference(_recordingStartTime!);
          final minutes = diff.inMinutes;
          final seconds = diff.inSeconds % 60;
          setState(
            () => _recordingDuration =
                '$minutes:${seconds.toString().padLeft(2, '0')}',
          );
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint('[Chat/Voice] Start error: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    try {
      final path = await _audioRecorder.stop();
      _recordingTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordingDuration = null;
      });
      if (path != null) {
        final duration = DateTime.now().difference(_recordingStartTime!);
        if (duration.inSeconds < 1) {
          _showIGToast('Hold longer to record');
          return;
        }
        _sendMediaMessage(path, 'voice', 'audio/m4a');
      }
    } catch (e) {
      debugPrint('[Chat/Voice] Stop error: $e');
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _pickAndSendMedia({
    bool fromCamera = false,
    bool isFile = false,
  }) async {
    try {
      String? path;
      String? type;
      String? mime;
      if (isFile) {
        final result = await FilePicker.pickFiles();
        if (result != null && result.files.single.path != null) {
          path = result.files.single.path;
          type = 'file';
          mime = 'application/octet-stream';
        }
      } else {
        final picker = ImagePicker();
        final XFile? file = await picker.pickImage(
          source: fromCamera ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 70,
        );
        if (file != null) {
          path = file.path;
          type = 'image';
          mime = 'image/jpeg';
        }
      }
      if (path != null && type != null) {
        if (type == 'image') {
          if (!mounted) return;
          final editedPath = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (context) => IGImageEditorScreen(imagePath: path!),
            ),
          );
          if (editedPath == null) return; // User backed out/cancelled
          path = editedPath;
        }
        _sendMediaMessage(path, type, mime!);
      }
    } catch (e) {
      _showIGToast('Error picking media');
    }
  }

  Future<void> _sendMediaMessage(
    String filePath,
    String type,
    String mime,
  ) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = Message(
      id: tempId,
      pairingId: _pairing!.id,
      senderId: _sb.currentUserId!,
      messageType: type,
      mediaUrl: filePath,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: {'pending': true, 'client_temp_id': tempId},
    );
    setState(() {
      _sending = true;
      _messages = [tempMsg, ..._messages];
    });
    _scrollToBottom();
    try {
      final remoteUrl = await _sb.uploadMessageMedia(
        _pairing!.id,
        tempId,
        filePath,
        mime,
      );
      await _sb.sendMessage(
        pairingId: _pairing!.id,
        messageType: type,
        mediaUrl: remoteUrl,
        metadata: {'client_temp_id': tempId},
      );
      if (_partner?.id != null) {
        final senderName =
            _partner?.preferences['partner_nickname'] ??
            _myProfile?.displayName ??
            'Someone';
        final mediaLabel = switch (type) {
          'image' => 'a photo',
          'voice' => 'a voice message',
          'video' => 'a video',
          'file' => 'a file',
          _ => 'media',
        };
        _maybeSendMessagePush(
          title: 'New media from $senderName',
          body: 'Sent $mediaLabel',
        );
      }
    } catch (e) {
      debugPrint('[Chat/Media] Upload error: $e');
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m.id == tempId));
        _showIGToast('Failed to send $type');
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _broadcastMyChatPresence(false);
    NotificationService.instance.clearActiveChat(
      pairingId: _pairing?.id,
      threadId: widget.threadId,
    );
    _toastEntry?.remove();
    _pickerOverlayEntry?.remove();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    _sendTypingStatus(false);
    _selfTypingHeartbeat?.cancel();
    _partnerTypingTimer?.cancel();
    _inactivityTimer?.cancel();
    _typingStreamSub?.cancel();
    _allReactionsSub?.cancel();
    _chatPresenceSub?.cancel();
    _highlightTimer?.cancel();
    _composerCtrl.dispose();
    _composerFocus.dispose();
    _scrollCtrl.dispose();
    _glowCtrl.dispose();
    _showComposerEmoji.dispose();
    _composerEmojiCat.dispose();
    _composerEmojiPageCtrl?.dispose();
    _messageSub?.cancel();
    _profileSub?.cancel();
    _presenceSub?.cancel();
    _presenceTimer?.cancel();
    _presenceDebounceTimer?.cancel();
    _emojiSearchCtrl.dispose();
    _searchCtrl.dispose();
    _showScrollToBottomNotifier.dispose();
    if (_typingPairingId != null) {
      _sb.releaseTypingChannel(_typingPairingId!);
    }
    if (_pairing != null) {
      _sb.disposeChatPresenceChannel(_pairing!.id);
    }
    _messageKeys.clear();
    _bubbleKeys.clear();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoadingState();
    if (_error != null) return _buildErrorState();

    return GestureDetector(
      onTap: _closeAllPickers,
      child: Scaffold(
        backgroundColor: const Color(
          0xFF0C0C15,
        ), // Midnight Obsidian Dark Background — prevents white keyboard flash
        extendBodyBehindAppBar: true,
        appBar: _buildHeader(),
        body: Stack(
          children: [
            // Static background pinned to absolute screen height — avoids expensive image rescaling during keyboard resize animations
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height,
              child: Image.asset(
                'assets/images/chatbground.jpg',
                fit: BoxFit.cover,
              ),
            ),
            // ClipRect absorbs any sub-pixel rounding overflow (e.g. 0.5px)
            ClipRect(
              child: Column(
                children: [
                  // Spacer so content sits BELOW the AppBar — floor() avoids
                  // fractional-pixel overflow from MediaQuery values.
                  SizedBox(
                    height:
                        (MediaQuery.of(context).padding.top + kToolbarHeight)
                            .floorToDouble(),
                  ),
                  if (_isSearchActive) _buildSearchBar(),
                  if (_pinnedMessages.isNotEmpty) _buildPinnedBar(),
                  Expanded(
                    child: Stack(
                      children: [
                        _messages.isEmpty
                            ? const _IGEmptyState()
                            : _buildMessageList(),
                        _ScrollToBottomButtonWidget(
                          showNotifier: _showScrollToBottomNotifier,
                          scrollCtrl: _scrollCtrl,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Typing indicator, reply preview, edit preview (above composer)
            Positioned(
              left: 0,
              right: 0,
              bottom: 70,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: _buildTypingIndicatorContent(),
                    crossFadeState: _isPartnerTyping
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: _replyTarget != null
                        ? _buildReplyPreviewContent(_replyTarget!)
                        : const SizedBox(width: double.infinity),
                    crossFadeState: _replyTarget != null
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 180),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: _editingMessage != null
                        ? _buildEditPreviewContent(_editingMessage!)
                        : const SizedBox(width: double.infinity),
                    crossFadeState: _editingMessage != null
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 180),
                  ),
                ],
              ),
            ),
            // Composer + emoji panel at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildComposer(),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    clipBehavior: Clip.hardEdge,
                    child: _buildComposerEmojiPanel(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEARCH
  // ─────────────────────────────────────────────────────────────────────────

  void _activateSearch() {
    setState(() {
      _isSearchActive = true;
      _searchQuery = '';
      _searchResultIds = [];
      _searchResultIndex = 0;
    });
    Future.delayed(const Duration(milliseconds: 80), () {
      // Autofocus is handled by the TextField's autofocus property
    });
  }

  void _deactivateSearch() {
    setState(() {
      _isSearchActive = false;
      _searchQuery = '';
      _searchResultIds = [];
      _searchResultIndex = 0;
    });
    _searchCtrl.clear();
  }

  void _onSearchChanged(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _searchResultIds = [];
        _searchResultIndex = 0;
      } else {
        _searchResultIds = _messages
            .where(
              (m) =>
                  m.content != null && m.content!.toLowerCase().contains(query),
            )
            .map((m) => m.id)
            .toList();
        _searchResultIndex = 0;
        if (_searchResultIds.isNotEmpty) {
          _scrollToMessage(_searchResultIds.first);
        }
      }
    });
  }

  void _searchNavigate(int delta) {
    if (_searchResultIds.isEmpty) return;
    final next = (_searchResultIndex + delta) % _searchResultIds.length;
    setState(() => _searchResultIndex = next);
    _scrollToMessage(_searchResultIds[next]);
  }

  Widget _buildSearchBar() {
    final resultCount = _searchResultIds.length;
    return Container(
      decoration: BoxDecoration(
        color: _IG.headerBg.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: _IG.headerBorder.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.of(context).padding.top > 0 ? 8 : 8,
        8,
        8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: _IG.fontSizeMd,
                ),
                decoration: InputDecoration(
                  hintText: 'Search messages…',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 18,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? Text(
                          '  ${resultCount == 0 ? '0' : _searchResultIndex + 1}/$resultCount  ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: _IG.fontSizeXs + 1,
                          ),
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          // Up arrow
          if (_searchResultIds.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.white70,
                size: 22,
              ),
              onPressed: () => _searchNavigate(1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          // Down arrow
          if (_searchResultIds.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white70,
                size: 22,
              ),
              onPressed: () => _searchNavigate(-1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          // Close
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white70,
              size: 20,
            ),
            onPressed: _deactivateSearch,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOADING / ERROR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: _IG.scaffoldBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(color: _IG.headerBg.withValues(alpha: 0.65)),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            color: _IG.headerBorder.withValues(alpha: 0.3),
            height: 0.5,
          ),
        ),
        title: Shimmer.fromColors(
          baseColor: _IG.skeletonBase,
          highlightColor: _IG.skeletonHighlight,
          child: Container(
            width: 120,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        reverse: true,
        itemCount: 8,
        itemBuilder: (_, i) => _IGChatSkeleton(isSent: i % 2 == 0),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: _IG.scaffoldBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: _IG.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              style: const TextStyle(
                color: _IG.textSecondary,
                fontSize: _IG.fontSizeMd,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  _error = null;
                  _loading = true;
                });
                _initializeChatAsync();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _IG.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildHeader() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(color: _IG.headerBg.withValues(alpha: 0.65)),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(
          color: _IG.headerBorder.withValues(alpha: 0.3),
          height: 0.5,
        ),
      ),
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _IG.headerText,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: _showProfileSheet,
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: _IG.inputBg,
                  child: _partner?.avatarUrl != null
                      ? ClipOval(
                          child: SizedBox(
                            width: 38,
                            height: 38,
                            child: SecureMediaImage(
                              value: _partner!.avatarUrl!,
                              fit: BoxFit.cover,
                              placeholder: _partnerAvatarInitial(),
                              errorWidget: _partnerAvatarInitial(),
                            ),
                          ),
                        )
                      : _partnerAvatarInitial(),
                ),
                if (_partnerOnline)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5AC85A),
                        shape: BoxShape.circle,
                        border: Border.all(color: _IG.headerBg, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _partnerName,
                    style: const TextStyle(
                      fontSize: _IG.fontSizeMd,
                      fontWeight: FontWeight.w700,
                      color: _IG.headerText,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _isPartnerTyping ? 'typing...' : _getLastSeenText(),
                    style: TextStyle(
                      fontSize: _IG.fontSizeXs + 1,
                      color: _isPartnerTyping ? _IG.blue : _IG.headerSubtext,
                      fontWeight: _isPartnerTyping
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.videocam_rounded,
            color: _IG.headerText,
            size: 26,
          ),
          onPressed: () => _startCall(isVideo: true),
        ),
        IconButton(
          icon: const Icon(
            Icons.phone_rounded,
            color: _IG.headerText,
            size: 22,
          ),
          onPressed: () => _startCall(isVideo: false),
        ),
        IconButton(
          icon: const Icon(
            Icons.more_vert_rounded,
            color: _IG.headerText,
            size: 24,
          ),
          onPressed: _showHeaderMenu,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PINNED BAR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPinnedBar() {
    return SizedBox(
      height: 54,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          // Match the header's dark tone — deep navy-black, same family as headerBg
          color: const Color(0xFF0E0E1A),
          border: Border(
            left: BorderSide(color: _IG.blue, width: 3),
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
        ),
        child: PageView.builder(
          itemCount: _pinnedMessages.length,
          itemBuilder: (context, index) {
            final msg = _pinnedMessages[index];
            final isMe = msg.metadata['pinned_by'] == _sb.currentUserId;
            // Hard-constrain each page item to exactly 54px so
            // fractional font line-heights can't cause overflow.
            return SizedBox(
              height: 54,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _scrollToMessage(msg.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6, // 6px gives 42px content area — safe margin
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.push_pin_rounded,
                          size: 13,
                          color: _IG.blue,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 2.5,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _IG.blue,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          margin: const EdgeInsets.only(right: 10),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Pinned by ${isMe ? 'You' : _partnerName}'
                                '${_pinnedMessages.length > 1 ? ' · ${index + 1}/${_pinnedMessages.length}' : ''}',
                                strutStyle: const StrutStyle(
                                  forceStrutHeight: true,
                                  height: 1.0,
                                ),
                                style: TextStyle(
                                  color: _IG.blue.withValues(alpha: 0.9),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                msg.content ?? 'Media',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                strutStyle: const StrutStyle(
                                  forceStrutHeight: true,
                                  height: 1.0,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _unpinMessage(msg.id),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MESSAGE LIST
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    // Top padding must clear AppBar (kToolbarHeight) + status bar so the
    // oldest (top-most) messages are never hidden under the header.
    final topClearance =
        MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    return RepaintBoundary(
      child: ListView.builder(
        controller: _scrollCtrl,
        reverse: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        padding: EdgeInsets.fromLTRB(12, topClearance, 12, 100),
        itemCount: _messages.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (_loadingMore && index == _messages.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _IG.blue,
                  ),
                ),
              ),
            );
          }

          final message = _messages[index];
          final isSent = message.senderId == _sb.currentUserId;

          bool showDateDivider = false;
          if (index == _messages.length - 1) {
            showDateDivider = true;
          } else {
            final prevMessage = _messages[index + 1];
            if (!_isSameDay(message.createdAt, prevMessage.createdAt)) {
              showDateDivider = true;
            }
          }

          final key = _messageKeys.putIfAbsent(message.id, () => GlobalKey());
          final replyTo = message.replyToId != null
              ? _messages.firstWhere(
                  (m) => m.id == message.replyToId,
                  orElse: () => message,
                )
              : null;

          final msgReactions = _reactions[message.id] ?? {};

          // Stable per-message GlobalKey for Overlay anchor positioning.
          // A fresh GlobalKey here re-created the key (and remounted the
          // bubble) on every rebuild.
          final bubbleKey = _bubbleKeys.putIfAbsent(
            message.id,
            () => GlobalKey(),
          );

          return Column(
            key: key,
            children: [
              if (showDateDivider) _buildDateDivider(message.createdAt),
              GestureDetector(
                onTap: _closeAllPickers,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  color: _highlightedMessageId == message.id
                      ? _IG.blue.withValues(alpha: 0.08)
                      : Colors.transparent,
                  child: _IGMessageBubble(
                    key: ValueKey(message.id),
                    bubbleKey: bubbleKey,
                    message: message,
                    isSent: isSent,
                    isPinned: _pinnedMessages.any((p) => p.id == message.id),
                    reactions: msgReactions,
                    myReaction: _myReactions[message.id],
                    isHighlighted: _highlightedMessageId == message.id,
                    replyToMessage: replyTo,
                    partnerName: _partnerName,
                    currentUserId: _sb.currentUserId ?? '',
                    onDoubleTap: () =>
                        _toggleQuickPicker(message.id, bubbleKey, isSent),
                    onLongPress: () => _openMessageActions(message),
                    onReply: () {
                      setState(() => _replyTarget = message);
                      Future.delayed(const Duration(milliseconds: 50), () {
                        if (mounted) _composerFocus.requestFocus();
                      });
                    },
                    onReplyTap: message.replyToId != null
                        ? () => _scrollToMessage(message.replyToId!)
                        : null,
                    onReaction: (emoji) => _toggleReaction(message.id, emoji),
                    showToast: _showIGToast,
                    onUpdateMetadata: _sb.updateMessageMetadata,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  Widget _buildDateDivider(DateTime date) {
    String text;
    final now = DateTime.now();
    final localDate = date.toLocal();
    if (_isSameDay(localDate, now)) {
      text = 'Today';
    } else if (_isSameDay(localDate, now.subtract(const Duration(days: 1)))) {
      text = 'Yesterday';
    } else {
      text = DateFormat('MMMM dd, yyyy').format(localDate);
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: _IG.fontSizeXs + 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TYPING INDICATOR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTypingIndicatorContent() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4, top: 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(20),
            ),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: const _IGTypingDots(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REPLY PREVIEW
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildReplyPreviewContent(Message replyTarget) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xEC0E0E1A), // Sleek Midnight Obsidian Glass Overlay
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            color: const Color(0xFF7C5FCC), // Core Deep Purple Accent
            margin: const EdgeInsets.only(right: 12),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  replyTarget.senderId == _sb.currentUserId
                      ? 'Reply to yourself'
                      : 'Reply to $_partnerName',
                  style: const TextStyle(
                    color: Color(0xFF7C5FCC), // Core Deep Purple Accent
                    fontSize: _IG.fontSizeSm,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  replyTarget.content ?? 'Media',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: _IG.fontSizeSm,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            onPressed: () => setState(() => _replyTarget = null),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EDIT PREVIEW
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEditPreviewContent(Message editingMessage) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xEC0E0E1A), // Sleek Midnight Obsidian Glass Overlay
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            color: const Color(0xFFF59E0B), // Warm Edit Gold Accent
            margin: const EdgeInsets.only(right: 12),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Editing',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: _IG.fontSizeSm,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  editingMessage.content ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: _IG.fontSizeSm,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            onPressed: _cancelEditingMessage,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMPOSER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildComposer() {
    // Use viewPadding (not padding) so the 3-button Android nav bar is
    // accounted for. viewPadding is static and won't cause rebuilds during
    // keyboard animation (unlike viewInsets).
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final extraBottom = safeBottom > 0 ? 12.0 : 8.0;

    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 8 + extraBottom),
      decoration: BoxDecoration(
        color: const Color(
          0xEC0A0A12,
        ), // Sleek, highly opaque Midnight Obsidian — matches the previews and avoids BackdropFilter GPU overhead
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.04,
                ), // Sophisticated dark input well
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _showComposerEmoji,
                    builder: (context, showEmoji, _) => IconButton(
                      icon: Icon(
                        showEmoji
                            ? Icons.keyboard_rounded
                            : Icons.emoji_emotions_outlined,
                        color: showEmoji
                            ? const Color(0xFF7C5FCC)
                            : Colors.white.withValues(alpha: 0.65),
                      ),
                      onPressed: _toggleComposerEmoji,
                    ),
                  ),
                  Expanded(
                    child: _isRecording
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.mic,
                                  color: _IG.errorRed,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _recordingDuration ?? '0:00',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Recording...',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : TextField(
                            key: _composerTextFieldKey,
                            controller: _composerCtrl,
                            focusNode: _composerFocus,
                            cursorColor: const Color(
                              0xFF7C5FCC,
                            ), // Core Deep Purple Accent Cursor
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: _IG.fontSizeMd,
                            ),
                            maxLines: 5,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: 'Message…',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                          ),
                  ),
                  if (!_isRecording) ...[
                    IconButton(
                      icon: Icon(
                        Icons.attach_file_rounded,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                      onPressed: _showAttachmentMenu,
                    ),
                    if (!_hasText)
                      IconButton(
                        icon: Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                        onPressed: () => _pickAndSendMedia(fromCamera: true),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecording(),
            onTap: () {
              if (_hasText) {
                _sendMessage();
              } else {
                _showIGToast('Hold to record voice');
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF7C5FCC), // Core Deep Purple Theme Color
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C5FCC).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                _hasText ? Icons.send_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMPOSER EMOJI PICKER (inline panel)
  // ─────────────────────────────────────────────────────────────────────────

  void _toggleComposerEmoji() {
    final opening = !_showComposerEmoji.value;
    _showComposerEmoji.value = opening;
    if (!opening) {
      // Switching back to keyboard
      _composerFocus.requestFocus();
    } else {
      // Switching to emoji panel — dismiss keyboard
      _composerFocus.unfocus();
    }
  }

  Widget _buildComposerEmojiPanel() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showComposerEmoji,
      builder: (context, show, _) {
        if (!show) return const SizedBox(height: 0, width: double.infinity);
        final cats = _kEmojiCategories;
        _composerEmojiPageCtrl ??= PageController();
        final pageCtrl = _composerEmojiPageCtrl!;

        return Container(
          height: 300,
          color: const Color(0xFF1E1E1E),
          child: Column(
            children: [
              // Category tabs
              SizedBox(
                height: 44,
                child: ValueListenableBuilder<int>(
                  valueListenable: _composerEmojiCat,
                  builder: (context, selectedCat, _) => ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: cats.length,
                    itemBuilder: (_, i) {
                      final isActive = i == selectedCat;
                      return GestureDetector(
                        onTap: () {
                          _composerEmojiCat.value = i;
                          pageCtrl.animateToPage(i,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.fastOutSlowIn);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: isActive
                              ? BoxDecoration(
                                  color: const Color(0xFF7C5FCC).withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF7C5FCC).withValues(alpha: 0.45),
                                    width: 0.8,
                                  ),
                                )
                              : null,
                          alignment: Alignment.center,
                          child: Text(cats[i]['icon'] as String,
                              style: TextStyle(fontSize: isActive ? 20 : 17)),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Container(height: 0.5, color: Colors.white.withValues(alpha: 0.10)),
              // Emoji grid
              Expanded(
                child: PageView.builder(
                  controller: pageCtrl,
                  itemCount: cats.length,
                  onPageChanged: (i) => _composerEmojiCat.value = i,
                  itemBuilder: (_, catI) {
                    final ems = List<String>.from(cats[catI]['emojis'] as List);
                    return GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemCount: ems.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () {
                          final text = _composerCtrl.text;
                          final sel = _composerCtrl.selection;
                          final start = sel.isValid ? sel.start : text.length;
                          final end = sel.isValid ? sel.end : text.length;
                          _composerCtrl.text =
                              '${text.substring(0, start)}${ems[i]}${text.substring(end)}';
                          _composerCtrl.selection =
                              TextSelection.collapsed(offset: start + ems[i].length);
                        },
                        child: Center(
                            child: Text(ems[i], style: const TextStyle(fontSize: 22))),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ATTACHMENT MENU
  // ─────────────────────────────────────────────────────────────────────────

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
            decoration: BoxDecoration(
              color: const Color(0xEC0A0A12),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: Wrap(
              spacing: 28,
              runSpacing: 28,
              alignment: WrapAlignment.center,
              children: [
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file_rounded,
                  color: const Color(0xFF8B5CF6),
                  label: 'Document',
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendMedia(isFile: true);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.image_rounded,
                  color: _IG.blue,
                  label: 'Photos',
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendMedia();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.gif_box_rounded,
                  color: const Color(0xFFE91E63),
                  label: 'GIF',
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendGif();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.emoji_emotions_rounded,
                  color: const Color(0xFFFF9800),
                  label: 'Sticker',
                  onTap: () {
                    Navigator.pop(context);
                    _showStickerPicker();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.poll_rounded,
                  color: const Color(0xFFF59E0B),
                  label: 'Poll',
                  onTap: () {
                    Navigator.pop(context);
                    _showPollDialog();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSendGif() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gif'],
      );
      if (result == null || result.files.single.path == null) return;
      final path = result.files.single.path!;
      _sendMediaMessage(path, 'image', 'image/gif');
    } catch (e) {
      _showIGToast('Error picking GIF');
    }
  }

  static const _kStickers = [
    '😍', '🥰', '😘', '😻', '🔥', '💕', '😂', '🥺',
    '😢', '😭', '🙈', '🙉', '🙊', '💝', '💖', '💗',
    '💓', '💞', '🤗', '😎', '🤩', '🥳', '🫶', '✨',
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🤍', '🖤',
    '👏', '🙌', '💪', '🤝', '👋', '✌️', '🤞', '🙏',
    '😢', '😡', '🤯', '😴', '🫡', '💅', '🌹', '⭐',
  ];

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.40,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Stickers',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(height: 0.5, color: Colors.white.withValues(alpha: 0.10)),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _kStickers.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _sendStickerMessage(_kStickers[i]);
                    },
                    child: Center(
                      child: Text(_kStickers[i], style: const TextStyle(fontSize: 36)),
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

  Future<void> _sendStickerMessage(String sticker) async {
    if (_pairing == null) return;
    await _sb.sendMessage(
      pairingId: _pairing!.id,
      messageType: 'sticker',
      content: sticker,
    );
    _scrollToBottom();
    if (_partner?.id != null) {
      final senderName =
          _partner?.preferences['partner_nickname'] ??
          _myProfile?.displayName ??
          'Someone';
      _maybeSendMessagePush(
        title: '💜 $senderName',
        body: 'Sent a sticker',
      );
    }
  }

  Future<void> _sendPollMessage(String question, List<String> options) async {
    try {
      await _sb.sendMessage(
        pairingId: _pairing!.id,
        messageType: 'text',
        content: question,
        metadata: {'is_poll': true, 'options': options, 'votes': {}},
      );
      _scrollToBottom();
    } catch (e) {
      debugPrint('[Chat/Poll] Error creating poll: $e');
      _showIGToast('Error creating poll');
    }
  }

  void _showPollDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _IGPollDialog(
          onCreate: (question, options) {
            _sendPollMessage(question, options);
          },
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: _IG.fontSizeSm,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROFILE SHEET
  // ─────────────────────────────────────────────────────────────────────────

  Widget _partnerAvatarInitial() {
    return Center(
      child: Text(
        _partnerName.isEmpty ? '?' : _partnerName[0].toUpperCase(),
        style: const TextStyle(
          color: _IG.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: _IG.fontSizeMd,
        ),
      ),
    );
  }

  void _showProfileSheet() {
    final avatarUrl = _partner?.avatarUrl;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (ctx, animation, _) {
          return FadeTransition(
            opacity: animation,
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              behavior: HitTestBehavior.opaque,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Stack(
                  children: [
                    // Fullscreen zoomable image
                    Center(
                      child: GestureDetector(
                        // Stop tap from bubbling up and dismissing while zooming
                        onTap: () {},
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 5.0,
                          child: avatarUrl != null
                              ? Hero(
                                  tag: 'partner_avatar',
                                  child: SecureMediaImage(
                                    value: avatarUrl,
                                    fit: BoxFit.contain,
                                    placeholder: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white54,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    errorWidget: _profileFallback(),
                                  ),
                                )
                              : _profileFallback(),
                        ),
                      ),
                    ),

                    // Top bar — name + close
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.of(ctx).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _partnerName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (_partner?.bio != null &&
                                    _partner!.bio!.isNotEmpty)
                                  Text(
                                    _partner!.bio!,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom hint
                    Positioned(
                      bottom: 32,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          'Pinch to zoom  ·  Tap to close',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.30),
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _profileFallback() {
    final initial = _partnerName.isEmpty ? '?' : _partnerName[0].toUpperCase();
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF7C5FCC), Color(0xFFF43F5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5FCC).withValues(alpha: 0.4),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  void _showHeaderMenu() {
    final RenderBox appBarBox = context.findRenderObject() as RenderBox;

    // Position the dropdown menu precisely at the top-right corner near the 3 dots
    final offset = Offset(
      appBarBox.size.width - 16,
      MediaQuery.of(context).padding.top + kToolbarHeight - 8,
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Menu',
      barrierColor: Colors.black.withValues(
        alpha: 0.18,
      ), // Ultra subtle dark backdrop tint
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              top: offset.dy,
              right: 16,
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
                alignment: Alignment.topRight,
                child: FadeTransition(
                  opacity: animation,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        width: 175,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xCC0E0E1A,
                          ), // Sleek Midnight Obsidian Glass
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildGlassMenuItem(
                              context: context,
                              icon: Icons.search_rounded,
                              label: 'Search',
                              onTap: () {
                                Navigator.pop(context);
                                _activateSearch();
                              },
                            ),
                            Container(
                              height: 0.5,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                            _buildGlassMenuItem(
                              context: context,
                              icon: Icons.photo_rounded,
                              label: 'Media',
                              onTap: () {
                                Navigator.pop(context);
                                _showMediaAndPinsView('media');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlassMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color textColor = Colors.white,
    Color? iconColor,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: iconColor ?? Colors.white.withValues(alpha: 0.85),
                size: 19,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: fontWeight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMediaAndPinsView(String viewType) {
    final isMedia = viewType == 'media';
    if (isMedia) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _MediaPage(
            messages: _messages,
            partnerName: _partnerName,
            onMessageTap: _scrollToMessage,
          ),
        ),
      );
    } else {
      final items = _pinnedMessages;
      final title = 'Pinned Messages (${items.length})';
      final emptyMessage = 'No pinned messages';

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: _IG.bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: _IG.fontSizeLg,
                        fontWeight: FontWeight.w600,
                        color: _IG.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close_rounded,
                        color: _IG.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: _IG.divider, height: 0.5),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    emptyMessage,
                    style: const TextStyle(
                      color: _IG.textSecondary,
                      fontSize: _IG.fontSizeMd,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final msg = items[index];
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.push_pin_rounded,
                                  color: _IG.blue,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg.content ?? 'Media',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _IG.textPrimary,
                                          fontSize: _IG.fontSizeMd,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat(
                                          'MMM d, h:mm a',
                                        ).format(msg.createdAt),
                                        style: const TextStyle(
                                          color: _IG.textSecondary,
                                          fontSize: _IG.fontSizeXs,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (index < items.length - 1)
                            Divider(color: _IG.divider, height: 0.5),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }

  String _getLastSeenText() {
    if (_partnerOnline) return 'Active now';
    final ts = _partnerLastSeen ?? _partner?.lastSeen ?? _partner?.updatedAt;
    if (ts == null) return 'Offline';
    final local = ts.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inDays == 0 && now.day == local.day) {
      return 'Active ${DateFormat('h:mm a').format(local)}';
    } else if (diff.inDays <= 1) {
      return 'Active yesterday';
    } else {
      return 'Active ${DateFormat('MMM d').format(local)}';
    }
  }
}

// =============================================================================
// IG MESSAGE BUBBLE
// =============================================================================

class _IGMessageBubble extends StatefulWidget {
  final GlobalKey bubbleKey;
  final Message message;
  final bool isSent;
  final bool isPinned;
  final Map<String, int> reactions;
  final String? myReaction;
  final bool isHighlighted;
  final Message? replyToMessage;
  final String partnerName;
  final String currentUserId;

  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final VoidCallback onReply;
  final VoidCallback? onReplyTap;
  final Function(String) onReaction;
  final Function(String) showToast;
  final Function(String, Map<String, dynamic>) onUpdateMetadata;

  const _IGMessageBubble({
    super.key,
    required this.bubbleKey,
    required this.message,
    required this.isSent,
    required this.isPinned,
    required this.reactions,
    required this.myReaction,
    required this.isHighlighted,
    required this.replyToMessage,
    required this.partnerName,
    required this.currentUserId,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onReply,
    required this.onReplyTap,
    required this.onReaction,
    required this.showToast,
    required this.onUpdateMetadata,
  });

  @override
  State<_IGMessageBubble> createState() => _IGMessageBubbleState();
}

class _IGMessageBubbleState extends State<_IGMessageBubble> {
  double _dragOffset = 0.0;
  bool _replyTriggered = false;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      if (!widget.isSent) {
        _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, 70.0);
      } else {
        _dragOffset = (_dragOffset + details.delta.dx).clamp(-70.0, 0.0);
      }
      if (_dragOffset.abs() >= 50 && !_replyTriggered) {
        _replyTriggered = true;
        HapticFeedback.lightImpact();
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    if (_replyTriggered) widget.onReply();
    setState(() {
      _dragOffset = 0;
      _replyTriggered = false;
    });
  }

  void _onHorizontalDragCancel() {
    setState(() {
      _dragOffset = 0;
      _replyTriggered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.message.metadata['pending'] == true;
    final hasReactions = widget.reactions.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(top: 2, bottom: hasReactions ? 28 : 4),
      child: GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        onHorizontalDragCancel: _onHorizontalDragCancel,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (_dragOffset.abs() > 10)
              Positioned(
                left: !widget.isSent ? 4 : null,
                right: widget.isSent ? 4 : null,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Opacity(
                    opacity: (_dragOffset.abs() / 50).clamp(0.0, 1.0),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _replyTriggered
                            ? _IG.blue.withValues(alpha: 0.12)
                            : _IG.inputBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.reply_rounded,
                        color: _replyTriggered ? _IG.blue : _IG.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),

            Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: Row(
                mainAxisAlignment: widget.isSent
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!widget.isSent) const SizedBox(width: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _buildBubbleWithQuote(isPending),
                            // Pin badge — small 📌 at the top corner of pinned bubbles
                            if (widget.isPinned)
                              Positioned(
                                top: -6,
                                left: widget.isSent ? null : -6,
                                right: widget.isSent ? -6 : null,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _IG.blue.withValues(alpha: 0.6),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.push_pin_rounded,
                                    size: 10,
                                    color: _IG.blue,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (hasReactions)
                        Positioned(
                          bottom: -20,
                          left: widget.isSent ? null : 6,
                          right: widget.isSent ? 6 : null,
                          child: _buildReactionBar(),
                        ),
                    ],
                  ),
                  if (widget.isSent) const SizedBox(width: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubbleWithQuote(bool isPending) {
    // If there's a reply, wrap in Column with header + preview above main bubble
    if (widget.replyToMessage != null) {
      return Column(
        crossAxisAlignment: widget.isSent
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildReplyHeaderAndPreview(widget.replyToMessage!),
          const SizedBox(height: 8),
          _buildMainBubble(isPending),
        ],
      );
    }
    return _buildMainBubble(isPending);
  }

  Widget _buildMainBubble(bool isPending) {
    // Stickers render without bubble chrome
    if (widget.message.messageType == 'sticker') {
      return Padding(
        key: widget.bubbleKey,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: _buildBubbleContent(isPending),
      );
    }

    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(
        widget.isSent ? _IG.radiusBubble : _IG.radiusBubbleTail,
      ),
      topRight: Radius.circular(
        widget.isSent ? _IG.radiusBubbleTail : _IG.radiusBubble,
      ),
      bottomLeft: const Radius.circular(_IG.radiusBubble),
      bottomRight: const Radius.circular(_IG.radiusBubble),
    );

    // Static layered approach — no BackdropFilter so blur never disappears
    // during scroll. Solid-feeling bubbles with a slight translucency.
    final Color baseColor = widget.isSent
        ? const Color(0xFF7C5FCC) // deep purple for sent
        : const Color(0xFF1C1C1E); // near-black for received
    final double baseAlpha = widget.isSent ? 0.78 : 0.82;

    return Container(
      key: widget.bubbleKey,
      decoration: BoxDecoration(
        // Frost base layer
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: borderRadius,
      ),
      child: Container(
        decoration: BoxDecoration(
          // Main solid tinted colour
          color: baseColor.withValues(alpha: baseAlpha),
          borderRadius: borderRadius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: _buildBubbleContent(isPending),
        ),
      ),
    );
  }

  Widget _buildReplyHeaderAndPreview(Message reply) {
    final isMe = reply.senderId == widget.currentUserId;
    final isMyReply = widget.currentUserId == widget.message.senderId;
    final headerText = isMe && isMyReply
        ? 'You replied to yourself'
        : isMyReply
        ? 'You replied'
        : '${widget.partnerName} replied';

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.85,
      ),
      child: Column(
        crossAxisAlignment: widget.isSent
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header label
          Text(
            headerText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: _IG.fontSizeSm - 1,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          // Preview bubble - glassmorphic dark
          GestureDetector(
            onTap: widget.onReplyTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  child: Text(
                    reply.content ?? 'Media',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: _IG.fontSizeSm,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildReplyQuote(Message reply) {
    final isMe = reply.senderId == widget.currentUserId;
    final accentColor = widget.isSent
        ? Colors.white.withValues(alpha: 0.85)
        : _IG.blue;
    final bgColor = widget.isSent
        ? Colors.white.withValues(alpha: 0.15)
        : _IG.blue.withValues(alpha: 0.08);

    return GestureDetector(
      onTap: widget.onReplyTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(left: BorderSide(color: accentColor, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMe ? 'You' : widget.partnerName,
              style: TextStyle(
                color: accentColor,
                fontSize: _IG.fontSizeXs + 1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              reply.content ?? 'Media',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.isSent
                    ? Colors.white.withValues(alpha: 0.75)
                    : _IG.textSecondary,
                fontSize: _IG.fontSizeSm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFileName(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
        if (name.isNotEmpty) {
          final decoded = Uri.decodeComponent(name);
          final extension = decoded.split('.').last.toUpperCase();
          if (extension.isNotEmpty && extension.length <= 4) {
            return 'Document ($extension)';
          }
          return decoded;
        }
      }
      final base = url.split(Platform.isWindows ? '\\' : '/').last;
      final extension = base.split('.').last.toUpperCase();
      if (extension.isNotEmpty && extension.length <= 4) {
        return 'Document ($extension)';
      }
      return base;
    } catch (_) {
      return 'Document';
    }
  }

  Widget _buildBubbleContent(bool isPending) {
    final textColor = Colors.white;
    final timeColor = Colors.white.withValues(alpha: 0.65);

    final timestamp = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.message.editedAt != null)
          Text(
            'edited · ',
            style: TextStyle(color: timeColor, fontSize: 10, height: 1),
          ),
        Text(
          DateFormat('h:mm a').format(
            (widget.message.editedAt ?? widget.message.createdAt).toLocal(),
          ),
          style: TextStyle(color: timeColor, fontSize: 10, height: 1),
        ),
        if (widget.isSent) ...[
          const SizedBox(width: 2),
          if (isPending)
            Icon(Icons.access_time_rounded, size: 12, color: timeColor)
          else
            Icon(
              widget.message.isRead
                  ? Icons.done_all_rounded
                  : Icons.done_rounded,
              size: 12,
              color: widget.message.isRead ? Colors.white : timeColor,
            ),
        ],
      ],
    );

    final bool isPoll =
        widget.message.messageType == 'poll' ||
        (widget.message.messageType == 'text' &&
            widget.message.metadata['is_poll'] == true);

    if (isPoll) {
      return _buildPollBubble(timestamp);
    }

    // Sticker — render large emoji without bubble chrome
    if (widget.message.messageType == 'sticker' &&
        widget.message.content != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            widget.message.content!,
            style: const TextStyle(fontSize: 72),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: timestamp,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.message.messageType == 'image' &&
            widget.message.mediaUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        IGImageViewerScreen(imageUrl: widget.message.mediaUrl!),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SecureMediaImage(
                  value: widget.message.mediaUrl!,
                  fit: BoxFit.cover,
                  width: 200,
                  height: 180,
                  placeholder: Container(
                    width: 200,
                    height: 180,
                    color: Colors.black.withValues(alpha: 0.1),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: Container(
                    width: 200,
                    height: 180,
                    color: Colors.black.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white60,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (widget.message.messageType == 'file' &&
            widget.message.mediaUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () async {
                final url = widget.message.mediaUrl!;
                try {
                  final isLocal =
                      !url.startsWith('http') && File(url).existsSync();
                  if (isLocal) {
                    widget.showToast('Document is uploading...');
                    return;
                  }
                  final resolved =
                      await SupabaseService().secureMediaUrl(url);
                  final uri = Uri.parse(resolved);
                  final success = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!success) {
                    widget.showToast('Cannot open document');
                  }
                } catch (e) {
                  widget.showToast('Cannot open document');
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C5FCC).withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF7C5FCC).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.insert_drive_file_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getFileName(widget.message.mediaUrl!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isPending ? 'Uploading...' : 'Tap to open document',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (widget.message.content != null)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: widget.message.content,
                  style: TextStyle(
                    color: textColor,
                    fontSize: _IG.fontSizeMd,
                    height: 1.4,
                  ),
                ),
                const TextSpan(text: '   '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: timestamp,
                ),
              ],
            ),
          ),
        if (widget.message.content == null)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: timestamp,
            ),
          ),
      ],
    );
  }

  Widget _buildPollBubble(Widget timestamp) {
    final question = widget.message.content ?? '';
    final options = List<String>.from(widget.message.metadata['options'] ?? []);
    final votes = Map<String, dynamic>.from(
      widget.message.metadata['votes'] ?? {},
    );
    final totalVotes = votes.length;

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Elegant Header Badge Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.poll_rounded,
                      color: Color(0xFFF59E0B),
                      size: 10,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'POLL',
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              // Glassmorphic interactive indicator icon
              Icon(
                Icons.how_to_vote_rounded,
                color: Colors.white.withValues(alpha: 0.25),
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Question text
          Text(
            question,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              height: 1.3,
              letterSpacing: 0.1,
            ),
          ),
          // Glass divider
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
          // Options List
          ...List.generate(options.length, (i) {
            final optionText = options[i];
            final optionVotes = votes.values.where((v) => v == i).length;
            final percentage = totalVotes > 0 ? optionVotes / totalVotes : 0.0;
            final hasVotedThis = votes[widget.currentUserId] == i;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  final newVotes = Map<String, dynamic>.from(votes);
                  final myId = widget.currentUserId;
                  if (newVotes[myId] == i) {
                    newVotes.remove(myId);
                  } else {
                    newVotes[myId] = i;
                  }
                  widget.onUpdateMetadata(widget.message.id, {
                    'votes': newVotes,
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 42,
                  decoration: BoxDecoration(
                    color: hasVotedThis
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasVotedThis
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: hasVotedThis
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.08),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final progressWidth = constraints.maxWidth * percentage;
                        return Stack(
                          children: [
                            // Progress bar indicator
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              width: progressWidth,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: hasVotedThis
                                      ? [
                                          const Color(
                                            0xFFF59E0B,
                                          ).withValues(alpha: 0.28),
                                          const Color(
                                            0xFFD97706,
                                          ).withValues(alpha: 0.12),
                                        ]
                                      : [
                                          Colors.white.withValues(alpha: 0.10),
                                          Colors.white.withValues(alpha: 0.03),
                                        ],
                                ),
                              ),
                            ),
                            // Option content
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  // Selected checkmark indicator
                                  if (hasVotedThis) ...[
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFFF59E0B),
                                      size: 15,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      optionText,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: hasVotedThis ? 1.0 : 0.85,
                                        ),
                                        fontSize: 13,
                                        fontWeight: hasVotedThis
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Count and percentage Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: hasVotedThis
                                          ? const Color(
                                              0xFFF59E0B,
                                            ).withValues(alpha: 0.15)
                                          : Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${(percentage * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: hasVotedThis
                                            ? const Color(0xFFF59E0B)
                                            : Colors.white.withValues(
                                                alpha: 0.6,
                                              ),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          // Footer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Live result status pill
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF59E0B),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    totalVotes == 1 ? '1 vote' : '$totalVotes votes',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              timestamp,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReactionBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: widget.reactions.entries.where((e) => e.value > 0).map((
              e,
            ) {
              final isMyPick = widget.myReaction == e.key;
              return GestureDetector(
                onTap: () => widget.onReaction(e.key),
                child: Container(
                  margin: const EdgeInsets.only(right: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: isMyPick
                      ? BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.key, style: const TextStyle(fontSize: 14)),
                      if (e.value > 1) ...[
                        const SizedBox(width: 2),
                        Text(
                          '${e.value}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// OVERLAY QUICK PICKER
// =============================================================================

class _OverlayQuickPicker extends StatelessWidget {
  final String msgId;
  final bool isSent;
  final Offset bubbleTopLeft;
  final Size bubbleSize;
  final String? myReaction;
  final String? customEmoji;
  final Function(String) onReaction;
  final VoidCallback onMoreEmoji;
  final VoidCallback onDismiss;

  const _OverlayQuickPicker({
    required this.msgId,
    required this.isSent,
    required this.bubbleTopLeft,
    required this.bubbleSize,
    required this.myReaction,
    this.customEmoji,
    required this.onReaction,
    required this.onMoreEmoji,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    const pickerH = 52.0;
    const gap = 8.0;
    double top = bubbleTopLeft.dy - pickerH - gap;
    if (top < MediaQuery.of(context).padding.top + 8) {
      top = bubbleTopLeft.dy + bubbleSize.height + gap;
    }

    const pickerW = 330.0;
    final screenW = MediaQuery.of(context).size.width;
    double left;
    if (isSent) {
      left = (bubbleTopLeft.dx + bubbleSize.width - pickerW).clamp(
        8.0,
        screenW - pickerW - 8,
      );
    } else {
      left = bubbleTopLeft.dx.clamp(8.0, screenW - pickerW - 8);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: top,
          left: left,
          child: _AnimatedPickerWrapper(
            child: Material(
              type: MaterialType.transparency,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._kQuickEmojis.map((em) {
                      final isSelected = myReaction == em;
                      return GestureDetector(
                        onTap: () => onReaction(em),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.all(5),
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: isSelected
                              ? BoxDecoration(
                                  color: _IG.blue.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(20),
                                )
                              : null,
                          child: Text(em, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    }),
                    // Show custom emoji if user has reacted with one
                    if (customEmoji != null) ...[
                      const SizedBox(width: 2),
                      GestureDetector(
                        onTap: () => onReaction(customEmoji!),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.all(5),
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: _IG.blue.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            customEmoji!,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onMoreEmoji,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// OVERLAY FULL PICKER
// =============================================================================

class _OverlayFullPicker extends StatefulWidget {
  final String msgId;
  final bool isSent;
  final Offset bubbleTopLeft;
  final Size bubbleSize;
  final String? myReaction;
  final int catIndex;
  final String searchQ;
  final TextEditingController searchCtrl;
  final Function(String) onReaction;
  final VoidCallback onDismiss;
  final Function(int) onCatChange;
  final Function(String) onSearch;

  const _OverlayFullPicker({
    required this.msgId,
    required this.isSent,
    required this.bubbleTopLeft,
    required this.bubbleSize,
    required this.myReaction,
    required this.catIndex,
    required this.searchQ,
    required this.searchCtrl,
    required this.onReaction,
    required this.onDismiss,
    required this.onCatChange,
    required this.onSearch,
  });

  @override
  State<_OverlayFullPicker> createState() => _OverlayFullPickerState();
}

class _OverlayFullPickerState extends State<_OverlayFullPicker> {
  late final PageController _pageCtrl;
  late final ScrollController _tabScrollCtrl;
  late int _activePage;

  @override
  void initState() {
    super.initState();
    _activePage = widget.catIndex;
    _tabScrollCtrl = ScrollController();
    _pageCtrl = PageController(initialPage: _activePage);
    _pageCtrl.addListener(() {
      final page = _pageCtrl.page?.round() ?? _activePage;
      if (page != _activePage && mounted) {
        setState(() => _activePage = page);
        // Notify parent so if picker is rebuilt the state persists
        widget.onCatChange(page);
        // Scroll the tabs bar to show the active category
        _scrollTabsToActiveCategory(page);
      }
    });
    // Scroll to initial category on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollTabsToActiveCategory(_activePage);
    });
  }

  void _scrollTabsToActiveCategory(int catIndex) {
    if (!_tabScrollCtrl.hasClients) return;
    // Each tab is roughly 60 pixels wide (icon + padding + margin)
    const tabWidth = 60.0;
    final tabListWidth = 310.0; // pickerW - some padding
    final targetOffset =
        (catIndex * tabWidth) - (tabListWidth / 2 - tabWidth / 2);
    _tabScrollCtrl.animateTo(
      targetOffset.clamp(0.0, _tabScrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _tabScrollCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goToPage(int i) {
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 180),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    const pickerH = 320.0;
    const pickerW = 310.0;
    const gap = 8.0;

    final cats = _kEmojiCategories;

    double top = widget.bubbleTopLeft.dy - pickerH - gap;
    if (top < MediaQuery.of(context).padding.top + 8) {
      top = widget.bubbleTopLeft.dy + widget.bubbleSize.height + gap;
    }

    final screenW = MediaQuery.of(context).size.width;
    double left;
    if (widget.isSent) {
      left = (widget.bubbleTopLeft.dx + widget.bubbleSize.width - pickerW)
          .clamp(8.0, screenW - pickerW - 8);
    } else {
      left = widget.bubbleTopLeft.dx.clamp(8.0, screenW - pickerW - 8);
    }

    return Stack(
      children: [
        // Backdrop dismiss
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),

        // Picker card
        Positioned(
          top: top,
          left: left,
          child: _AnimatedPickerWrapper(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: pickerW,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.50),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Category tab bar (scrolls away with emojis) ──────────────────────────────
                      SizedBox(
                        height: 48,
                        child: ListView.builder(
                          controller: _tabScrollCtrl,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          itemCount: cats.length,
                          itemBuilder: (_, i) {
                            final isActive = _activePage == i;
                            return GestureDetector(
                              onTap: () => _goToPage(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: isActive
                                    ? BoxDecoration(
                                        color: const Color(
                                          0xFF7C5FCC,
                                        ).withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF7C5FCC,
                                          ).withValues(alpha: 0.45),
                                          width: 0.8,
                                        ),
                                      )
                                    : null,
                                alignment: Alignment.center,
                                child: Text(
                                  cats[i]['icon'] as String,
                                  style: TextStyle(
                                    fontSize: isActive ? 20 : 17,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Thin divider
                      Container(
                        height: 0.5,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),

                      // ── Emoji PageView with scrollable height ────────────────────────
                      SizedBox(
                        height: 250,
                        child: PageView.builder(
                          controller: _pageCtrl,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          itemCount: cats.length,
                          itemBuilder: (_, catI) {
                            final List<String> emojis = List<String>.from(
                              cats[catI]['emojis'] as List,
                            );
                            if (emojis.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No emojis',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: _IG.fontSizeSm,
                                  ),
                                ),
                              );
                            }
                            return GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.all(8),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 8,
                                    childAspectRatio: 1,
                                    mainAxisSpacing: 2,
                                    crossAxisSpacing: 2,
                                  ),
                              itemCount: emojis.length,
                              itemBuilder: (_, i) {
                                final em = emojis[i];
                                final isSelected = widget.myReaction == em;
                                return GestureDetector(
                                  onTap: () => widget.onReaction(em),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 100),
                                    decoration: isSelected
                                        ? BoxDecoration(
                                            color: _IG.blue.withValues(
                                              alpha: 0.30,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          )
                                        : null,
                                    child: Center(
                                      child: Text(
                                        em,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),

                      // ── Pill dot indicator ───────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(cats.length, (i) {
                            final isActive = i == _activePage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: isActive ? 18 : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF7C5FCC)
                                    : Colors.white.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// IG ACTION SHEET
// =============================================================================

class _IGActionSheet extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isPinned;
  final bool canEdit;
  final String? myReaction;
  final String partnerName;
  final String currentUserId;

  final Function(String) onReaction;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onPin;
  final VoidCallback? onEdit;
  final VoidCallback? onUnsend;

  const _IGActionSheet({
    required this.message,
    required this.isMe,
    required this.isPinned,
    required this.canEdit,
    required this.myReaction,
    required this.partnerName,
    required this.currentUserId,
    required this.onReaction,
    required this.onReply,
    required this.onCopy,
    required this.onPin,
    required this.onEdit,
    required this.onUnsend,
  });

  @override
  Widget build(BuildContext context) {
    final senderName = message.senderId == currentUserId ? 'You' : partnerName;
    final isMyMsg = message.senderId == currentUserId;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.10),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(99),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMyMsg
                        ? _IG.blue.withValues(alpha: 0.15)
                        : _IG.inputBg,
                  ),
                  child: Center(
                    child: Text(
                      senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: isMyMsg ? _IG.blue : Colors.white60,
                        fontWeight: FontWeight.w700,
                        fontSize: _IG.fontSizeMd,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            senderName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: _IG.fontSizeSm,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat(
                              'h:mm a',
                            ).format(message.createdAt.toLocal()),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: _IG.fontSizeXs,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message.content ?? 'Media',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: _IG.fontSizeSm,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(height: 0.5, color: Colors.white.withValues(alpha: 0.08)),

          _actionItem(
            icon: Icons.reply_rounded,
            label: 'Reply',
            onTap: onReply,
          ),
          _divider(),
          if (message.messageType == 'text' &&
              message.metadata['is_poll'] != true) ...[
            _actionItem(icon: Icons.copy_rounded, label: 'Copy', onTap: onCopy),
            _divider(),
          ],
          _actionItem(
            icon: isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            label: isPinned ? 'Unpin' : 'Pin',
            onTap: onPin,
          ),
          if (canEdit && onEdit != null) ...[
            _divider(),
            _actionItem(
              icon: Icons.edit_rounded,
              label: 'Edit',
              onTap: onEdit!,
            ),
          ],
          if (isMe && onUnsend != null) ...[
            _divider(),
            _actionItem(
              icon: Icons.delete_rounded,
              label: 'Unsend',
              isDestructive: true,
              onTap: onUnsend!,
            ),
          ],

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _actionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isDestructive ? _IG.errorRed : Colors.white,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: _IG.fontSizeMd,
                color: isDestructive ? _IG.errorRed : Colors.white,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
    height: 0.5,
    color: Colors.white.withValues(alpha: 0.08),
    margin: const EdgeInsets.symmetric(horizontal: 20),
  );
}

// =============================================================================
// ANIMATED PICKER WRAPPER
// =============================================================================

class _AnimatedPickerWrapper extends StatefulWidget {
  final Widget child;
  const _AnimatedPickerWrapper({required this.child});
  @override
  State<_AnimatedPickerWrapper> createState() => _AnimatedPickerWrapperState();
}

class _AnimatedPickerWrapperState extends State<_AnimatedPickerWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// =============================================================================
// IG ALERT DIALOG
// =============================================================================

class _IGDialogAction {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDestructive;
  const _IGDialogAction({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.isDestructive = false,
  });
}

class _IGAlertDialog extends StatelessWidget {
  final String title;
  final String? content;
  final Widget? customContent;
  final List<_IGDialogAction> actions;

  const _IGAlertDialog({
    required this.title,
    required this.content,
    this.customContent,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: _IG.fontSizeLg,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (content != null) ...[
              const SizedBox(height: 10),
              Text(
                content!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: _IG.fontSizeMd,
                  height: 1.45,
                ),
              ),
            ],
            if (customContent != null) ...[
              const SizedBox(height: 8),
              customContent!,
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions.map((a) {
                return TextButton(
                  onPressed: a.onTap,
                  child: Text(
                    a.label,
                    style: TextStyle(
                      color: a.isDestructive
                          ? _IG.errorRed
                          : (a.isPrimary
                                ? _IG.blue
                                : Colors.white.withValues(alpha: 0.6)),
                      fontWeight: a.isPrimary || a.isDestructive
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// IG TOAST
// =============================================================================

class _IGToast extends StatefulWidget {
  final String message;
  const _IGToast({required this.message});
  @override
  State<_IGToast> createState() => _IGToastState();
}

class _IGToastState extends State<_IGToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _dismissTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted && !_ctrl.isAnimating) {
        _ctrl.reverse();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(_anim),
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF262626).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: _IG.fontSizeSm,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// IG EMPTY STATE
// =============================================================================

class _IGEmptyState extends StatelessWidget {
  const _IGEmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _IG.inputBg,
                shape: BoxShape.circle,
                border: Border.all(color: _IG.headerBorder, width: 0.5),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 32,
                color: _IG.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Message text is end-to-end encrypted.\nNo one outside your devices can read it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _IG.textSecondary,
                fontSize: _IG.fontSizeSm,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// IG TYPING DOTS
// =============================================================================

class _IGTypingDots extends StatefulWidget {
  const _IGTypingDots();
  @override
  State<_IGTypingDots> createState() => _IGTypingDotsState();
}

class _IGTypingDotsState extends State<_IGTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) {
            final val = sin((_ctrl.value * 2 * pi) - (i * 0.8));
            final opacity = ((val + 1) / 2).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: _IG.textSecondary.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

// =============================================================================
// IG SKELETON
// =============================================================================

class _IGChatSkeleton extends StatelessWidget {
  final bool isSent;
  const _IGChatSkeleton({required this.isSent});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _IG.skeletonBase,
      highlightColor: _IG.skeletonHighlight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: isSent
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Container(
              width: isSent ? 180 : 220,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SCROLL TO BOTTOM BUTTON WIDGET
// =============================================================================

class _ScrollToBottomButtonWidget extends StatefulWidget {
  final ValueNotifier<bool> showNotifier;
  final ScrollController scrollCtrl;

  const _ScrollToBottomButtonWidget({
    required this.showNotifier,
    required this.scrollCtrl,
  });

  @override
  State<_ScrollToBottomButtonWidget> createState() =>
      _ScrollToBottomButtonWidgetState();
}

class _ScrollToBottomButtonWidgetState
    extends State<_ScrollToBottomButtonWidget> {
  @override
  void initState() {
    super.initState();
    widget.showNotifier.addListener(_onNotifierChanged);
  }

  void _onNotifierChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_ScrollToBottomButtonWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showNotifier != widget.showNotifier) {
      oldWidget.showNotifier.removeListener(_onNotifierChanged);
      widget.showNotifier.addListener(_onNotifierChanged);
    }
  }

  @override
  void dispose() {
    widget.showNotifier.removeListener(_onNotifierChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 90,
      right: 16,
      child: Opacity(
        opacity: widget.showNotifier.value ? 1.0 : 0.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: widget.showNotifier.value
                  ? () {
                      if (widget.scrollCtrl.hasClients) {
                        widget.scrollCtrl.animateTo(
                          0,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    }
                  : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _IG.inputBg,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_downward_rounded,
                    color: Colors.black,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MEDIA PAGE
// =============================================================================

class _MediaPage extends StatefulWidget {
  final List<Message> messages;
  final String partnerName;
  final Function(String) onMessageTap;

  const _MediaPage({
    required this.messages,
    required this.partnerName,
    required this.onMessageTap,
  });

  @override
  State<_MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<_MediaPage> {
  late List<String> _selectedMediaTypes;
  bool _sortAscending = false; // false = newest first, true = oldest first
  late List<Message> _filteredMessages;

  static const List<String> _allMediaTypes = [
    'image',
    'video',
    'audio',
    'sticker',
    'file',
  ];
  static const Map<String, IconData> _typeIcons = {
    'image': Icons.image_rounded,
    'video': Icons.videocam_rounded,
    'audio': Icons.audiotrack_rounded,
    'sticker': Icons.emoji_emotions_rounded,
    'file': Icons.insert_drive_file_rounded,
  };

  @override
  void initState() {
    super.initState();
    _selectedMediaTypes = List.from(_allMediaTypes);
    _updateFilteredMessages();
  }

  void _updateFilteredMessages() {
    _filteredMessages = widget.messages
        .where((m) => _selectedMediaTypes.contains(m.messageType))
        .toList();

    if (_sortAscending) {
      _filteredMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      _filteredMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    if (mounted) setState(() {});
  }

  Map<String, List<Message>> _groupByDate(List<Message> messages) {
    final grouped = <String, List<Message>>{};
    for (final msg in messages) {
      final date = DateFormat('MMMM d, yyyy').format(msg.createdAt);
      grouped.putIfAbsent(date, () => []).add(msg);
    }
    return grouped;
  }

  void _toggleMediaType(String type) {
    setState(() {
      if (_selectedMediaTypes.contains(type)) {
        _selectedMediaTypes.remove(type);
      } else {
        _selectedMediaTypes.add(type);
      }
      _updateFilteredMessages();
    });
  }

  void _toggleSort() {
    setState(() {
      _sortAscending = !_sortAscending;
      _updateFilteredMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF0C0C15,
      ), // Deep Midnight Obsidian Background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A), // Matches headerBg dark tone
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Shared Gallery',
          style: const TextStyle(
            color: Colors.white,
            fontSize: _IG.fontSizeLg,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            color: Colors.white.withValues(alpha: 0.08),
            height: 0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter chips & sort button row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Sort button
                GestureDetector(
                  onTap: _toggleSort,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sort_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _sortAscending ? 'Oldest first' : 'Newest first',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Media type filter chips
                ..._allMediaTypes.map((type) {
                  final isSelected = _selectedMediaTypes.contains(type);
                  return GestureDetector(
                    onTap: () => _toggleMediaType(type),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _IG.blue
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? _IG.blue
                              : Colors.white.withValues(alpha: 0.08),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _typeIcons[type],
                            size: 14,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            type == 'image'
                                ? 'Photos'
                                : (type == 'file' ? 'Docs' : type.capitalize()),
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Container(height: 0.5, color: Colors.white.withValues(alpha: 0.08)),
          // Media list grouped by date
          if (_filteredMessages.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      color: Colors.white.withValues(alpha: 0.25),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No media files found',
                      style: TextStyle(
                        fontSize: _IG.fontSizeMd,
                        color: Colors.white.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _groupByDate(_filteredMessages).entries.length,
                itemBuilder: (context, index) {
                  final entries = _groupByDate(
                    _filteredMessages,
                  ).entries.toList();
                  final dateEntry = entries[index];
                  final date = dateEntry.key;
                  final messagesForDate = dateEntry.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                        child: Text(
                          date,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.45),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      // Media grid for this date
                      GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: messagesForDate.length,
                        itemBuilder: (context, idx) {
                          final msg = messagesForDate[idx];
                          return _buildMediaTile(msg);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaTile(Message msg) {
    final bool isImage =
        msg.messageType == 'image' &&
        msg.mediaUrl != null &&
        msg.mediaUrl!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          widget.onMessageTap(msg.id);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image preview or beautifully color-coded media icons
              if (isImage)
                SecureMediaImage(
                  value: msg.mediaUrl!,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: Colors.white.withValues(alpha: 0.04),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: _IG.blue,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: Container(
                    color: Colors.white.withValues(alpha: 0.04),
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white24,
                        size: 26,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  color: Colors.white.withValues(alpha: 0.03),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getFileTypeColor(
                          msg.messageType,
                        ).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _typeIcons[msg.messageType] ??
                            Icons.insert_drive_file_rounded,
                        color: _getFileTypeColor(msg.messageType),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              // Title and Time overlay at the bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(8, 20, 8, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          msg.content != null &&
                                  msg.content!.isNotEmpty &&
                                  msg.messageType != 'image'
                              ? msg.content!
                              : (msg.messageType == 'image'
                                    ? 'Photo'
                                    : msg.messageType.capitalize()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('h:mm a').format(msg.createdAt),
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getFileTypeColor(String type) {
    switch (type) {
      case 'video':
        return const Color(0xFFFF453A);
      case 'audio':
        return const Color(0xFF30D158);
      case 'file':
        return const Color(0xFFBF5AF2);
      default:
        return _IG.blue;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

// =============================================================================
// POLL DIALOG
// =============================================================================

class _IGPollDialog extends StatefulWidget {
  final Function(String, List<String>) onCreate;
  const _IGPollDialog({required this.onCreate});

  @override
  State<_IGPollDialog> createState() => _IGPollDialogState();
}

class _IGPollDialogState extends State<_IGPollDialog> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  void _addOption() {
    if (_optionControllers.length >= 6) {
      return;
    }
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) {
      return;
    }
    setState(() {
      _optionControllers.removeAt(index);
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xEC0A0A12), // Dark Obsidian Glass
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.poll_rounded,
                          color: Color(0xFFF59E0B),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Create Poll',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Question',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _questionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      hintText: 'Ask a question...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFF59E0B),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Options',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...List.generate(_optionControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _optionControllers[index],
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                hintText: 'Option ${index + 1}',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFF59E0B),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_optionControllers.length > 2) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _removeOption(index),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  if (_optionControllers.length < 6) ...[
                    const SizedBox(height: 4),
                    TextButton.icon(
                      icon: const Icon(
                        Icons.add_rounded,
                        color: Color(0xFFF59E0B),
                      ),
                      label: const Text(
                        'Add Option',
                        style: TextStyle(color: Color(0xFFF59E0B)),
                      ),
                      onPressed: _addOption,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () {
                          final question = _questionController.text.trim();
                          final options = _optionControllers
                              .map((c) => c.text.trim())
                              .where((t) => t.isNotEmpty)
                              .toList();
                          if (question.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please ask a question'),
                              ),
                            );
                            return;
                          }
                          if (options.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please provide at least 2 options',
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context);
                          widget.onCreate(question, options);
                        },
                        child: const Text(
                          'Create',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
