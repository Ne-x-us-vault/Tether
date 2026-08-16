// ══════════════════════════════════════════════════════════════════════════════
// supabase_service.dart — Lovit App
// Comprehensive backend service for all Supabase operations
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/constants/supabase_constants.dart';
import 'encryption_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════════════════════════════════════════

class UserProfile {
  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final int? batteryLevel;
  final DateTime? batteryLastUpdated;
  final bool locationSharingEnabled;
  final double? currentLatitude;
  final double? currentLongitude;
  final DateTime? locationLastUpdated;
  final Map<String, dynamic> preferences;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOnline;
  final DateTime? lastSeen;

  UserProfile({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.batteryLevel,
    this.batteryLastUpdated,
    this.locationSharingEnabled = false,
    this.currentLatitude,
    this.currentLongitude,
    this.locationLastUpdated,
    this.preferences = const {},
    required this.createdAt,
    required this.updatedAt,
    this.isOnline = false,
    this.lastSeen,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final updatedAt = DateTime.parse(json['updated_at']);
    final isOnlineDb = json['is_online'] ?? false;

    // Heartbeat occurs every 20 seconds. If it hasn't updated in 3 minutes (180 seconds),
    // they are likely offline (app was force-quit or lost connection).
    // We use .abs() to be safe from client clock being slightly ahead or behind.
    bool actualOnline = isOnlineDb;
    if (isOnlineDb) {
      final now = DateTime.now().toUtc();
      final diff = now.difference(updatedAt.toUtc());
      if (diff.inSeconds.abs() > 180) {
        actualOnline = false;
      }
    }

    return UserProfile(
      id: json['id'],
      username: json['username'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      batteryLevel: json['battery_level'],
      batteryLastUpdated: json['battery_last_updated'] != null
          ? DateTime.parse(json['battery_last_updated'])
          : null,
      locationSharingEnabled: json['location_sharing_enabled'] ?? false,
      currentLatitude: json['current_latitude'],
      currentLongitude: json['current_longitude'],
      locationLastUpdated: json['location_last_updated'] != null
          ? DateTime.parse(json['location_last_updated'])
          : null,
      preferences: json['preferences'] ?? {},
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: updatedAt,
      isOnline: actualOnline,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'bio': bio,
    'battery_level': batteryLevel,
    'battery_last_updated': batteryLastUpdated?.toIso8601String(),
    'location_sharing_enabled': locationSharingEnabled,
    'current_latitude': currentLatitude,
    'current_longitude': currentLongitude,
    'location_last_updated': locationLastUpdated?.toIso8601String(),
    'preferences': preferences,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'is_online': isOnline,
    'last_seen': lastSeen?.toIso8601String(),
  };

  UserProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    int? batteryLevel,
    DateTime? batteryLastUpdated,
    bool? locationSharingEnabled,
    double? currentLatitude,
    double? currentLongitude,
    DateTime? locationLastUpdated,
    Map<String, dynamic>? preferences,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      batteryLastUpdated: batteryLastUpdated ?? this.batteryLastUpdated,
      locationSharingEnabled:
          locationSharingEnabled ?? this.locationSharingEnabled,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      locationLastUpdated: locationLastUpdated ?? this.locationLastUpdated,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

/// Battery update model for real-time partner battery tracking
class BatteryUpdate {
  final String userId;
  final int level; // 0-100
  final DateTime lastUpdated;

  BatteryUpdate({
    required this.userId,
    required this.level,
    required this.lastUpdated,
  });

  @override
  String toString() =>
      'BatteryUpdate(user: $userId, level: $level%, at: $lastUpdated)';
}

class Pairing {
  final String id;
  final String user1Id;
  final String? user2Id;
  final String pairingCode;
  final String status; // 'pending', 'active', 'inactive'
  final DateTime? pairedAt;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Pairing({
    required this.id,
    required this.user1Id,
    this.user2Id,
    required this.pairingCode,
    required this.status,
    this.pairedAt,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Pairing.fromJson(Map<String, dynamic> json) {
    return Pairing(
      id: json['id'],
      user1Id: json['user1_id'],
      user2Id: json['user2_id'],
      pairingCode: json['pairing_code'],
      status: json['status'],
      pairedAt: json['paired_at'] != null
          ? DateTime.parse(json['paired_at'])
          : null,
      expiresAt: DateTime.parse(json['expires_at']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class Message {
  final String id;
  final String pairingId;
  final String senderId;
  final String
  messageType; // 'text', 'image', 'voice', 'video', 'location', 'file'
  final String? content;
  final String? mediaUrl;
  final Map<String, dynamic> metadata;
  final bool isRead;
  final DateTime? readAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? replyToId;
  final DateTime? editedAt;
  final Map<String, dynamic>? editHistory;
  final DateTime createdAt;
  final DateTime updatedAt;

  Message({
    required this.id,
    required this.pairingId,
    required this.senderId,
    this.messageType = 'text',
    this.content,
    this.mediaUrl,
    this.metadata = const {},
    this.isRead = false,
    this.readAt,
    this.isDeleted = false,
    this.deletedAt,
    this.replyToId,
    this.editedAt,
    this.editHistory,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      pairingId: json['pairing_id'],
      senderId: json['sender_id'],
      messageType: json['message_type'] ?? 'text',
      content: json['content'],
      mediaUrl: json['media_url'],
      metadata: json['metadata'] ?? {},
      isRead: json['is_read'] ?? false,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      isDeleted: json['is_deleted'] ?? false,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
      replyToId: json['reply_to_id'],
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'])
          : null,
      editHistory: json['edit_history'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'pairing_id': pairingId,
    'sender_id': senderId,
    'message_type': messageType,
    'content': content,
    'media_url': mediaUrl,
    'metadata': metadata,
    'reply_to_id': replyToId,
  };
}

class MessageReaction {
  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      id: json['id'],
      messageId: json['message_id'],
      userId: json['user_id'],
      emoji: json['emoji'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'message_id': messageId,
    'user_id': userId,
    'emoji': emoji,
  };
}

class Task {
  final String id;
  final String pairingId;
  final String createdBy;
  final String? assignedTo;
  final String title;
  final String? description;
  final String priority; // 'low', 'medium', 'high'
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? completedBy;
  final int position;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.pairingId,
    required this.createdBy,
    this.assignedTo,
    required this.title,
    this.description,
    this.priority = 'medium',
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    this.completedBy,
    this.position = 0,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      pairingId: json['pairing_id'],
      createdBy: json['created_by'],
      assignedTo: json['assigned_to'],
      title: json['title'],
      description: json['description'],
      priority: json['priority'] ?? 'medium',
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : null,
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      completedBy: json['completed_by'],
      position: json['position'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'pairing_id': pairingId,
    'created_by': createdBy,
    'assigned_to': assignedTo,
    'title': title,
    'description': description,
    'priority': priority,
    'due_date': dueDate?.toIso8601String(),
    'is_completed': isCompleted,
    'completed_at': completedAt?.toIso8601String(),
    'completed_by': completedBy,
    'position': position,
    'tags': tags,
  };

  Task copyWith({
    String? id,
    String? pairingId,
    String? createdBy,
    String? assignedTo,
    String? title,
    String? description,
    String? priority,
    DateTime? dueDate,
    bool? isCompleted,
    DateTime? completedAt,
    String? completedBy,
    int? position,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      pairingId: pairingId ?? this.pairingId,
      createdBy: createdBy ?? this.createdBy,
      assignedTo: assignedTo ?? this.assignedTo,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      position: position ?? this.position,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CalendarEvent {
  final String id;
  final String pairingId;
  final String createdBy;
  final String title;
  final String? description;
  final String? location;
  final DateTime startTime;
  final DateTime endTime;
  final bool allDay;
  final String color;
  final List<int> reminderMinutes;
  final bool isRecurring;
  final String? recurrenceRule;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  CalendarEvent({
    required this.id,
    required this.pairingId,
    required this.createdBy,
    required this.title,
    this.description,
    this.location,
    required this.startTime,
    required this.endTime,
    this.allDay = false,
    this.color = '#B39DFF',
    this.reminderMinutes = const [],
    this.isRecurring = false,
    this.recurrenceRule,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'],
      pairingId: json['pairing_id'],
      createdBy: json['created_by'],
      title: json['title'],
      description: json['description'],
      location: json['location'],
      // Stored as UTC; convert to local so calendar day-grouping compares
      // local-vs-local (isSameDay) regardless of device timezone.
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: DateTime.parse(json['end_time']).toLocal(),
      allDay: json['all_day'] ?? false,
      color: json['color'] ?? '#B39DFF',
      reminderMinutes: List<int>.from(json['reminder_minutes'] ?? []),
      isRecurring: json['is_recurring'] ?? false,
      recurrenceRule: json['recurrence_rule'],
      metadata: json['metadata'] ?? {},
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'pairing_id': pairingId,
    'created_by': createdBy,
    'title': title,
    'description': description,
    'location': location,
    // Normalize to UTC before persisting so the timestamptz column holds an
    // unambiguous instant for both partners.
    'start_time': startTime.toUtc().toIso8601String(),
    'end_time': endTime.toUtc().toIso8601String(),
    'all_day': allDay,
    'color': color,
    'reminder_minutes': reminderMinutes,
    'is_recurring': isRecurring,
    'recurrence_rule': recurrenceRule,
    'metadata': metadata,
  };
}

class PeriodLog {
  final String id;
  final String userId;
  final String? pairingId;
  final DateTime cycleStartDate;
  final int cycleLength;
  final int periodLength;
  final String? flowLevel;
  final List<String>? symptoms;
  final String? mood;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  DateTime get startDate => cycleStartDate;
  DateTime get endDate => cycleStartDate.add(Duration(days: periodLength - 1));

  PeriodLog({
    required this.id,
    required this.userId,
    this.pairingId,
    required this.cycleStartDate,
    this.cycleLength = 28,
    this.periodLength = 5,
    this.flowLevel,
    this.symptoms,
    this.mood,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PeriodLog.fromJson(Map<String, dynamic> json) {
    return PeriodLog(
      id: json['id'],
      userId: json['user_id'],
      pairingId: json['pairing_id'],
      cycleStartDate: DateTime.parse(json['cycle_start_date']),
      cycleLength: json['cycle_length'] ?? 28,
      periodLength: json['period_length'] ?? 5,
      flowLevel: json['flow_level'],
      symptoms: json['symptoms'] != null
          ? List<String>.from(json['symptoms'])
          : null,
      mood: json['mood'],
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    if (pairingId != null) 'pairing_id': pairingId,
    'cycle_start_date': cycleStartDate.toIso8601String().split('T').first,
    'cycle_length': cycleLength,
    'period_length': periodLength,
    if (flowLevel != null) 'flow_level': flowLevel,
    if (symptoms != null) 'symptoms': symptoms,
    if (mood != null) 'mood': mood,
    if (notes != null) 'notes': notes,
  };
}

class BudgetEntry {
  final String id;
  final String pairingId;
  final String createdBy;
  final String? paidByUserId;
  final String title;
  final double amount;
  final String category;
  final DateTime transactionDate;
  final String? notes;
  final bool isShared;
  final DateTime createdAt;
  final DateTime updatedAt;

  DateTime get spentAt => transactionDate;
  String get effectivePaidByUserId => paidByUserId ?? createdBy;

  BudgetEntry({
    required this.id,
    required this.pairingId,
    required this.createdBy,
    this.paidByUserId,
    required this.title,
    required this.amount,
    required this.category,
    required this.transactionDate,
    this.notes,
    this.isShared = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BudgetEntry.fromJson(Map<String, dynamic> json) {
    return BudgetEntry(
      id: json['id'],
      pairingId: json['pairing_id'],
      createdBy: json['created_by'],
      paidByUserId:
          json['paid_by'] as String? ?? json['paid_by_user_id'] as String?,
      title: json['title'] ?? '',
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] ?? 'other',
      transactionDate: json['transaction_date'] != null
          ? DateTime.parse(json['transaction_date'])
          : DateTime.parse(json['created_at']),
      notes: json['notes'],
      isShared: json['is_shared'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'pairing_id': pairingId,
    'created_by': createdBy,
    if (paidByUserId != null) 'paid_by': paidByUserId,
    'title': title,
    'amount': amount,
    'category': category,
    'transaction_date': transactionDate.toIso8601String(),
    'notes': notes,
    'is_shared': isShared,
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// SUPABASE SERVICE
// ══════════════════════════════════════════════════════════════════════════════

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _connectivityListening = false;

  void _initConnectivityListener() {
    if (_connectivityListening) return;
    _connectivityListening = true;
    Connectivity().onConnectivityChanged.listen((results) {
      // Results is a List<ConnectivityResult> in newer versions
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        debugPrint(
          '[Supabase] Internet restored. Triggering global refresh...',
        );
        // client.realtime.connect() is internal. The SDK usually handles reconnection,
        // but we trigger a manual refresh for our listeners.
        _onReconnect.add(null);
      }
    });
  }

  SupabaseClient get client {
    _initConnectivityListener();
    return Supabase.instance.client;
  }
  User? get currentUser => client.auth.currentUser;

  /// Restores the persisted auth session in a fresh background isolate so
  /// Workmanager tasks can authenticate. No-op if a session is already present.
  static Future<void> restoreBackgroundSession() async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final host = Uri.parse(SupabaseConstants.url).host.split('.').first;
      final sessionStr = prefs.getString('sb-$host-auth-token');
      if (sessionStr != null) {
        await client.auth.recoverSession(sessionStr);
      }
    } catch (e) {
      debugPrint('[Auth] restoreBackgroundSession failed: $e');
    }
  }
  String? get currentUserId => currentUser?.id;

  // Global refresh trigger for when internet returns
  final _onReconnect = StreamController<void>.broadcast();
  Stream<void> get onReconnect => _onReconnect.stream;

  final _profileUpdateController = StreamController<UserProfile>.broadcast();
  final _budgetUpdateController = StreamController<void>.broadcast();

  static SharedPreferences? _prefs;
  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Synchronous access to prefs if already initialized.
  SharedPreferences? get prefsSync => _prefs;

  // Serializes presence writes so a slow "offline" write can never land after a
  // newer "online" write (and vice-versa), preventing stuck offline states.
  Future<void> _lastPresenceWrite = Future.value();
  Future<void> _enqueuePresenceWrite(Future<void> Function() action) {
    final next = _lastPresenceWrite.then((_) => action());
    _lastPresenceWrite = next.catchError((_) {});
    return next;
  }

  // Marks this session's profile row as known-to-exist once confirmed, so the
  // frequent presence/battery/location writes stop issuing an extra GET.
  bool _profileRowExists = false;

  // Throttled SharedPreferences writer for large realtime payloads. On busy
  // tables (messages/tasks/calendar/period logs) we persist the latest snapshot
  // at most once per [kCacheWriteInterval] instead of on every event.
  static const _kCacheWriteInterval = Duration(seconds: 2);
  final Map<String, Timer> _cacheWriteTimers = {};
  final Map<String, List<dynamic>> _pendingCacheWrites = {};

  void _throttledCacheWrite(String key, List<dynamic> value) {
    if (_cacheWriteTimers.containsKey(key)) {
      _pendingCacheWrites[key] = value;
      return;
    }
    _writeCacheNow(key, value);
    _cacheWriteTimers[key] = Timer(_kCacheWriteInterval, () {
      _cacheWriteTimers.remove(key);
      final pending = _pendingCacheWrites.remove(key);
      if (pending != null) {
        _writeCacheNow(key, pending);
      }
    });
  }

  void _writeCacheNow(String key, List<dynamic> value) {
    prefsSync?.setString(key, jsonEncode(value)).ignore();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // AUTH
  // ────────────────────────────────────────────────────────────────────────────

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'signup_time': DateTime.now().toUtc().toIso8601String()},
    );
  }

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out current user
  Future<void> signOut() async {
    _signedUrlCache.clear();
    await client.auth.signOut();
  }

  /// Check if user is already authenticated
  bool get isAuthenticated => client.auth.currentSession != null;

  /// Check if current user's email is verified
  bool get isEmailVerified => currentUser?.emailConfirmedAt != null;

  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // ────────────────────────────────────────────────────────────────────────────
  // PROFILE
  // ────────────────────────────────────────────────────────────────────────────

  UserProfile? _myProfileMemCache;

  Future<UserProfile?> getMyProfile() async {
    final p = await prefs;
    const cacheKey = 'cache_my_profile';

    if (_myProfileMemCache != null) {
      _refreshMyProfileBg();
      return _myProfileMemCache;
    }

    final cachedStr = p.getString(cacheKey);
    if (cachedStr != null) {
      try {
        _myProfileMemCache = UserProfile.fromJson(jsonDecode(cachedStr));
        _refreshMyProfileBg();
        return _myProfileMemCache;
      } catch (_) {}
    }

    return await _refreshMyProfileBg();
  }

  Future<UserProfile?> _refreshMyProfileBg() async {
    if (currentUserId == null) return null;
    try {
      final p = await prefs;
      final response = await client
          .from('profiles')
          .select()
          .eq('id', currentUserId!)
          .maybeSingle()
          .timeout(const Duration(seconds: 2));

      if (response != null) {
        p.setString('cache_my_profile', jsonEncode(response)).ignore();
        _myProfileMemCache = UserProfile.fromJson(response);
        return _myProfileMemCache;
      }
    } catch (e) {
      debugPrint('[Cache] Error refreshing my profile bg: $e');
    }
    return _myProfileMemCache;
  }

  Future<UserProfile?> getPartnerProfile(String pairingId) async {
    final p = await prefs;
    final cacheKey = 'cache_partner_profile_$pairingId';

    if (currentUserId == null) {
      final cachedStr = p.getString(cacheKey);
      if (cachedStr != null) {
        return UserProfile.fromJson(jsonDecode(cachedStr));
      }
      return null;
    }

    try {
      final pairing = await getPairing(pairingId);
      if (pairing == null) return null;
      final partnerId = pairing.user1Id == currentUserId
          ? pairing.user2Id
          : pairing.user1Id;
      if (partnerId == null) return null;
      final response = await client
          .from('profiles')
          .select()
          .eq('id', partnerId)
          .maybeSingle()
          .timeout(const Duration(seconds: 2));
      if (response != null) {
        p.setString(cacheKey, jsonEncode(response)).ignore();
        return UserProfile.fromJson(response);
      }
    } catch (e) {
      debugPrint('[Cache] Error fetching partner profile: $e. Using cache.');
    }

    final cachedStr = p.getString(cacheKey);
    if (cachedStr != null) {
      return UserProfile.fromJson(jsonDecode(cachedStr));
    }
    return null;
  }

  Future<UserProfile> upsertProfile(UserProfile profile) async {
    final response = await client
        .from('profiles')
        .upsert(profile.toJson())
        .select()
        .single();
    return UserProfile.fromJson(response);
  }

  Future<void> _ensureProfileRow() async {
    if (currentUserId == null) return;
    if (_profileRowExists || _myProfileMemCache != null) return;
    final existing = await getMyProfile();
    if (existing != null) {
      _profileRowExists = true;
      return;
    }

    final created = await upsertProfile(
      UserProfile(
        id: currentUserId!,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    _profileRowExists = true;
    _myProfileMemCache = created;
    final p = await prefs;
    p.setString('cache_my_profile', jsonEncode(created.toJson())).ignore();
  }

  /// Marks the current user as online in the DB.
  Future<void> setOnline() async {
    if (currentUserId == null) return;
    await _enqueuePresenceWrite(() async {
      try {
        await _ensureProfileRow();
        await client
            .from('profiles')
            .update({
              'is_online': true,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', currentUserId!);
        // Instant broadcast for real-time UI updates
        broadcastPresenceChange(isOnline: true);
      } catch (e) {
        debugPrint('[Presence] setOnline failed: $e');
      }
    });
  }

  /// Marks the current user as offline and records last_seen timestamp.
  Future<void> setOffline() async {
    if (currentUserId == null) return;
    await _enqueuePresenceWrite(() async {
      try {
        await _ensureProfileRow();
        await client
            .from('profiles')
            .update({
              'is_online': false,
              'last_seen': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', currentUserId!);
      } catch (e) {
        debugPrint('[Presence] setOffline failed: $e');
      }
    });
  }

  /// Saves the FCM push token to the private push_tokens table (SEC-17).
  /// The token is no longer stored on the public-readable profiles row.
  Future<void> saveFcmToken(String token) async {
    if (currentUserId == null) return;
    try {
      await client.from('push_tokens').upsert({
        'user_id': currentUserId!,
        'token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('[FCM] Token saved to Supabase');
    } catch (e) {
      debugPrint('[FCM] Token save error: $e');
    }
  }

  /// Calls the Supabase Edge Function `send-notification` to push a
  /// notification to [toUserId] with the given [type], [title] and [body].
  /// [data] is an optional extra payload forwarded to the app on tap.
  Future<void> sendPushNotification({
    required String toUserId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await client.functions.invoke(
        'send-notification',
        body: {
          'to_user_id': toUserId,
          'type': type,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );
      debugPrint('[Push] Sent $type notification to $toUserId');
    } catch (e) {
      debugPrint('[Push] Error sending notification: $e');
    }
  }

  /// Fetches the current user's notifications from the database.
  Future<List<Map<String, dynamic>>> getNotifications() async {
    if (currentUserId == null) return [];
    try {
      final response = await client
          .from('notifications')
          .select()
          .eq('user_id', currentUserId!)
          .order('created_at', ascending: false)
          .limit(200);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[Notifications] Error fetching notifications: $e');
      return [];
    }
  }

  /// Realtime stream of notifications for the current user.
  Stream<List<Map<String, dynamic>>> watchNotifications() {
    if (currentUserId == null) return Stream.value([]);

    // Create a broadcast stream controller
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    // Fetch generation counter so a slow in-flight fetch can never overwrite a
    // newer one that completed first.
    int generation = 0;

    // Helper to fetch latest and emit
    void fetchAndEmit() async {
      final myGeneration = ++generation;
      final notifs = await getNotifications();
      if (!controller.isClosed && myGeneration == generation) {
        controller.add(notifs);
      }
    }

    // Fetch initial
    fetchAndEmit();

    // Subscribe to Postgres Changes for notifications
    final channel = client
        .channel('public_notifications_user_$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: currentUserId!,
          ),
          callback: (payload) {
            fetchAndEmit();
          },
        );

    channel.subscribe();

    controller.onCancel = () {
      channel.unsubscribe();
      controller.close();
    };

    return controller.stream;
  }

  /// Marks a specific notification as read.
  Future<void> markNotificationAsRead(String id) async {
    try {
      await client.from('notifications').update({'is_read': true}).eq('id', id);
    } catch (e) {
      debugPrint('[Notifications] Error marking notification as read: $e');
    }
  }

  /// Deletes a specific notification.
  Future<void> deleteNotification(String id) async {
    try {
      await client.from('notifications').delete().eq('id', id);
    } catch (e) {
      debugPrint('[Notifications] Error deleting notification: $e');
    }
  }

  /// Clears all notifications for the current user.
  Future<void> clearAllNotifications() async {
    if (currentUserId == null) return;
    try {
      await client.from('notifications').delete().eq('user_id', currentUserId!);
    } catch (e) {
      debugPrint('[Notifications] Error clearing notifications: $e');
    }
  }

  /// Realtime stream of a partner's presence (is_online + last_seen).
  /// Uses BOTH Postgres Changes (reliable, eventual) AND broadcast events
  /// (instant, via _profileUpdateController) so offline/online is detected
  /// immediately when the partner minimises/opens the app.
  Stream<UserProfile> watchPartnerPresence(String partnerId) {
    final controller = StreamController<UserProfile>.broadcast();
    UserProfile? currentProfile;
    DateTime lastHeartbeatReceived = DateTime.now();
    Timer? watchdogTimer;

    void updateProfile(UserProfile profile) {
      currentProfile = profile;
      if (profile.isOnline) {
        lastHeartbeatReceived = DateTime.now();
      }
      if (!controller.isClosed) {
        controller.add(profile);
      }
    }

    // Start a watchdog timer to detect silent disconnects (every 10 seconds)
    watchdogTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (currentProfile != null && currentProfile!.isOnline) {
        final silenceDuration = DateTime.now().difference(lastHeartbeatReceived);
        // If we haven't heard a heartbeat or update in 45 seconds, mark the partner offline locally
        if (silenceDuration.inSeconds > 45) {
          final offlineProfile = currentProfile!.copyWith(
            isOnline: false,
            lastSeen: lastHeartbeatReceived.toUtc(),
          );
          updateProfile(offlineProfile);
        }
      }
    });

    // 1. Fetch initial state immediately from DB
    client
        .from('profiles')
        .select()
        .eq('id', partnerId)
        .single()
        .then((data) {
          if (!controller.isClosed) {
            try {
              final profile = UserProfile.fromJson(data);
              updateProfile(profile);
            } catch (_) {}
          }
        })
        .catchError((_) {});

    // 2. Subscribe to realtime Postgres Changes (eventual consistency)
    final channel = client
        .channel('partner_presence_$partnerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: partnerId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            if (data.isNotEmpty && !controller.isClosed) {
              try {
                final profile = UserProfile.fromJson(data);
                updateProfile(profile);
              } catch (_) {}
            }
          },
        )
        .subscribe();

    // 3. ALSO subscribe to broadcast-driven profile updates for INSTANT
    //    online/offline signalling (fired by broadcastPresenceChange).
    final broadcastSub = _profileUpdateController.stream.listen((updated) {
      if (updated.id == partnerId && !controller.isClosed) {
        updateProfile(updated);
      }
    });

    controller.onCancel = () {
      watchdogTimer?.cancel();
      client.removeChannel(channel);
      broadcastSub.cancel();
    };

    return controller.stream;
  }

  /// Realtime stream of a partner's battery level (battery_level + battery_last_updated).
  /// Emits updates whenever the partner's battery changes, even when app is backgrounded.
  /// Uses BOTH Postgres Changes (reliable, eventual) AND broadcast events (instant).
  Stream<BatteryUpdate> watchPartnerBattery(String partnerId) {
    final controller = StreamController<BatteryUpdate>.broadcast();

    // 1. Fetch initial state immediately from DB
    client
        .from('profiles')
        .select()
        .eq('id', partnerId)
        .single()
        .then((data) {
          if (!controller.isClosed) {
            try {
              final profile = UserProfile.fromJson(data);
              if (profile.batteryLevel != null) {
                controller.add(
                  BatteryUpdate(
                    userId: partnerId,
                    level: profile.batteryLevel!,
                    lastUpdated: profile.batteryLastUpdated ?? DateTime.now(),
                  ),
                );
              }
            } catch (_) {}
          }
        })
        .catchError((_) {});

    // 2. Subscribe to realtime Postgres Changes (eventual consistency)
    final channel = client
        .channel('partner_battery_$partnerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: partnerId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            if (data.isNotEmpty && !controller.isClosed) {
              try {
                final profile = UserProfile.fromJson(data);
                if (profile.batteryLevel != null) {
                  controller.add(
                    BatteryUpdate(
                      userId: partnerId,
                      level: profile.batteryLevel!,
                      lastUpdated: profile.batteryLastUpdated ?? DateTime.now(),
                    ),
                  );
                }
              } catch (_) {}
            }
          },
        )
        .subscribe();

    // 3. ALSO subscribe to broadcast-driven profile updates for INSTANT battery updates
    final broadcastSub = _profileUpdateController.stream.listen((updated) {
      if (updated.id == partnerId &&
          !controller.isClosed &&
          updated.batteryLevel != null) {
        controller.add(
          BatteryUpdate(
            userId: partnerId,
            level: updated.batteryLevel!,
            lastUpdated: updated.batteryLastUpdated ?? DateTime.now(),
          ),
        );
      }
    });

    controller.onCancel = () {
      client.removeChannel(channel);
      broadcastSub.cancel();
    };

    return controller.stream;
  }

  /// Stores the user's E2EE public key in their profile preferences so
  /// partners can derive the shared message key.
  Future<void> uploadE2eePublicKey(String publicKeyB64) async {
    if (currentUserId == null) {
      throw Exception('User must be logged in to upload encryption key');
    }
    final profile = await getMyProfile();
    final preferences = Map<String, dynamic>.from(
      profile?.preferences ?? <String, dynamic>{},
    );
    preferences['e2ee_pubkey'] = publicKeyB64;
    await updateProfile(preferences: preferences);
  }

  /// Applies E2EE decryption to a message's content, falling back to the
  /// original payload when it is legacy plaintext or cannot be decrypted.
  Future<Message> _decryptMessage(Message message) async {
    final content = await EncryptionService.instance.decryptFromPairing(
      message.pairingId,
      message.content,
    );
    if (content == message.content) return message;
    return Message(
      id: message.id,
      pairingId: message.pairingId,
      senderId: message.senderId,
      messageType: message.messageType,
      content: content,
      mediaUrl: message.mediaUrl,
      metadata: message.metadata,
      isRead: message.isRead,
      readAt: message.readAt,
      isDeleted: message.isDeleted,
      deletedAt: message.deletedAt,
      replyToId: message.replyToId,
      editedAt: message.editedAt,
      editHistory: message.editHistory,
      createdAt: message.createdAt,
      updatedAt: message.updatedAt,
    );
  }

  Future<List<Message>> _decryptMessages(
    String pairingId,
    List<Message> messages,
  ) async {
    final out = <Message>[];
    for (final message in messages) {
      out.add(await _decryptMessage(message));
    }
    return out;
  }

  Future<UserProfile> updateProfile({
    String? displayName,
    String? username,
    String? avatarUrl,
    String? bio,
    Map<String, dynamic>? preferences,
  }) async {
    if (currentUserId == null) {
      throw Exception('User must be logged in to update profile');
    }
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (displayName != null) updates['display_name'] = displayName;
    if (username != null) updates['username'] = username;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (bio != null) updates['bio'] = bio;
    if (preferences != null) updates['preferences'] = preferences;

    Map<String, dynamic>? response;

    try {
      response = await client
          .from('profiles')
          .update(updates)
          .eq('id', currentUserId!)
          .select()
          .maybeSingle();
    } catch (e) {
      // Surface the failure to the caller instead of clobbering the DB profile
      // with a stale cached copy (which previously could flip is_online/location).
      debugPrint('[Profile] updateProfile failed: $e');
      rethrow;
    }

    if (response == null) {
      throw Exception('Profile update failed: no row returned');
    }

    final updatedProfile = UserProfile.fromJson(response);
    _myProfileMemCache = updatedProfile;
    final p = await prefs;
    p.setString('cache_my_profile', jsonEncode(response)).ignore();

    try {
      final activePairingStr = p.getString('cache_active_pairing');
      if (activePairingStr != null) {
        final pairing = Pairing.fromJson(jsonDecode(activePairingStr));
        final key1 = 'cache_profiles_${pairing.user1Id}_${pairing.user2Id}';
        final key2 = 'cache_profiles_${pairing.user2Id}_${pairing.user1Id}';
        for (final k in [key1, key2]) {
          final str = p.getString(k);
          if (str != null) {
            final List<dynamic> list = jsonDecode(str);
            final newList = list.map((item) {
              if (item['id'] == currentUserId) {
                return response;
              }
              return item;
            }).toList();
            p.setString(k, jsonEncode(newList)).ignore();
          }
        }
      }
    } catch (_) {}

    _profileUpdateController.add(updatedProfile);

    return updatedProfile;
  }

  Stream<List<UserProfile>> watchProfiles(List<String> userIds) {
    if (userIds.isEmpty) {
      return Stream.value(const <UserProfile>[]);
    }

    initRealtimeAppUpdates();

    final controller = StreamController<List<UserProfile>>.broadcast();
    List<UserProfile> currentProfiles = [];

    StreamSubscription<List<Map<String, dynamic>>>? streamSub;
    StreamSubscription<UserProfile>? localSub;
    bool disposed = false;

    // Set onCancel synchronously so a listener that cancels before the async
    // SharedPreferences fetch resolves still cleans up all subscriptions.
    controller.onCancel = () {
      disposed = true;
      streamSub?.cancel();
      localSub?.cancel();
    };

    SharedPreferences.getInstance().then((prefs) {
      final cacheKey = 'cache_profiles_${userIds.join('_')}';
      try {
        final cachedStr = prefs.getString(cacheKey);
        if (cachedStr != null) {
          final List<dynamic> decoded = jsonDecode(cachedStr);
          currentProfiles = decoded
              .map((json) => UserProfile.fromJson(json as Map<String, dynamic>))
              .toList();
          currentProfiles.sort(
            (a, b) => userIds.indexOf(a.id).compareTo(userIds.indexOf(b.id)),
          );
          if (currentProfiles.isNotEmpty && !controller.isClosed) {
            controller.add(List.from(currentProfiles));
          }
        }
      } catch (_) {}

      streamSub = client
          .from('profiles')
          .stream(primaryKey: ['id'])
          .listen((data) {
            final profiles = data
                .where((json) => userIds.contains(json['id']))
                .map<UserProfile>((json) {
                  final Map<String, dynamic> mutableJson =
                      Map<String, dynamic>.from(json);
                  final existingIdx = currentProfiles.indexWhere(
                    (p) => p.id == mutableJson['id'],
                  );
                  if (existingIdx != -1) {
                    final existing = currentProfiles[existingIdx];
                    final dbTime = DateTime.parse(
                      mutableJson['updated_at'] as String,
                    );
                    if (existing.updatedAt.isAfter(dbTime)) {
                      // Cached profile is newer (e.g. updated by broadcast).
                      // Preserve presence fields so the stale DB poll doesn't
                      // overwrite an instant offline/online signal.
                      mutableJson['updated_at'] = existing.updatedAt
                          .toIso8601String();
                      mutableJson['is_online'] = existing.isOnline;
                      if (existing.lastSeen != null) {
                        mutableJson['last_seen'] = existing.lastSeen!
                            .toIso8601String();
                      }
                    }
                  }
                  return UserProfile.fromJson(mutableJson);
                })
                .toList();

            if (profiles.isNotEmpty) {
              prefs.setString(cacheKey, jsonEncode(profiles)).ignore();
              profiles.sort(
                (a, b) =>
                    userIds.indexOf(a.id).compareTo(userIds.indexOf(b.id)),
              );
              currentProfiles = profiles;
              if (!controller.isClosed) {
                controller.add(List.from(currentProfiles));
              }
            }
          });

      localSub = _profileUpdateController.stream.listen((updated) {
        if (userIds.contains(updated.id)) {
          final idx = currentProfiles.indexWhere((p) => p.id == updated.id);
          if (idx != -1) {
            currentProfiles[idx] = updated;
          } else {
            currentProfiles.add(updated);
          }
          currentProfiles.sort(
            (a, b) => userIds.indexOf(a.id).compareTo(userIds.indexOf(b.id)),
          );
          if (!controller.isClosed) {
            controller.add(List.from(currentProfiles));
          }
          prefs.setString(cacheKey, jsonEncode(currentProfiles)).ignore();
        }
      });

      if (disposed) {
        streamSub?.cancel();
        localSub?.cancel();
        return;
      }
    });

    return controller.stream;
  }

  Future<void> updateBatteryLevel(int level) async {
    if (currentUserId == null) return;
    await _ensureProfileRow();
    await client
        .from('profiles')
        .update({
          'battery_level': level,
          'battery_last_updated': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', currentUserId!);
  }

  Future<void> updateLocation(
    double lat,
    double lng, {
    bool? sharingEnabled,
  }) async {
    if (currentUserId == null) return;
    await _ensureProfileRow();
    final updates = <String, dynamic>{
      'current_latitude': lat,
      'current_longitude': lng,
      'location_last_updated': DateTime.now().toUtc().toIso8601String(),
    };
    if (sharingEnabled != null) {
      updates['location_sharing_enabled'] = sharingEnabled;
    }
    await client.from('profiles').update(updates).eq('id', currentUserId!);
  }

  Future<void> updateLocationSharingEnabled(bool enabled) async {
    if (currentUserId == null) return;
    await _ensureProfileRow();
    await client
        .from('profiles')
        .update({
          'location_sharing_enabled': enabled,
          'location_last_updated': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', currentUserId!);

    if (enabled) {
      try {
        final pairing = await getActivePairing();
        if (pairing != null) {
          final partnerId = pairing.user1Id == currentUserId
              ? pairing.user2Id
              : pairing.user1Id;
          if (partnerId != null && partnerId.isNotEmpty) {
            final myProfile = await getMyProfile();
            final partnerProfile = await getPartnerProfile(pairing.id);
            final senderName =
                partnerProfile?.preferences['partner_nickname'] ??
                myProfile?.displayName ??
                'Your partner';
            unawaited(
              sendPushNotification(
                toUserId: partnerId,
                type: 'location',
                title: '🗺️ Partner location shared',
                body: '$senderName is now sharing their live location',
              ),
            );
          }
        }
      } catch (_) {}
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // PAIRING
  // ────────────────────────────────────────────────────────────────────────────

  Future<Pairing> createPairing() async {
    if (currentUserId == null) {
      throw Exception('User must be logged in to create pairing');
    }

    final code = _generatePairingCode();
    final expiresAt = DateTime.now()
        .add(const Duration(hours: 24))
        .toUtc()
        .toIso8601String();

    final response = await client
        .from('pairings')
        .insert({
          'user1_id': currentUserId,
          'pairing_code': code,
          'status': 'pending',
          'expires_at': expiresAt,
        })
        .select()
        .single();
    return Pairing.fromJson(response);
  }

  String _generatePairingCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = math.Random.secure();
    return List.generate(6, (i) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<Pairing> joinPairing(String code) async {
    if (currentUserId == null) {
      throw Exception('User must be logged in to join pairing');
    }
    // Claim is validated and made atomic on the server (RPC `join_pairing`):
    // pending + not expired + user2_id still null, under a row lock.
    try {
      final response = await client.rpc(
        'join_pairing',
        params: {'p_code': code.toUpperCase()},
      );
      if (response == null) {
        throw Exception('Invalid or expired pairing code');
      }
      return Pairing.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Invalid or expired pairing code');
    }
  }

  Future<Pairing?> getActivePairing() async {
    final p = await prefs;
    const cacheKey = 'cache_active_pairing';

    if (currentUserId == null) {
      final cachedStr = p.getString(cacheKey);
      if (cachedStr != null) {
        return Pairing.fromJson(jsonDecode(cachedStr));
      }
      return null;
    }

    try {
      final response = await client
          .from('pairings')
          .select()
          .or('user1_id.eq.$currentUserId,user2_id.eq.$currentUserId')
          .eq('status', 'active')
          .maybeSingle()
          .timeout(const Duration(seconds: 2));

      if (response != null) {
        p.setString(cacheKey, jsonEncode(response)).ignore();
        return Pairing.fromJson(response);
      }
      // Server answered authoritatively: there is no active pairing. Do NOT
      // fall back to a stale cached pairing that may have been deleted/expired.
      p.remove(cacheKey).ignore();
      return null;
    } catch (e) {
      debugPrint('[Cache] Error fetching active pairing: $e. Using cache.');
    }

    final cachedStr = p.getString(cacheKey);
    if (cachedStr != null) {
      return Pairing.fromJson(jsonDecode(cachedStr));
    }
    return null;
  }

  Future<Pairing?> getPairing(String pairingId) async {
    final p = await prefs;
    final cacheKey = 'cache_pairing_$pairingId';

    try {
      final response = await client
          .from('pairings')
          .select()
          .eq('id', pairingId)
          .maybeSingle()
          .timeout(const Duration(seconds: 2));
      if (response != null) {
        p.setString(cacheKey, jsonEncode(response)).ignore();
        return Pairing.fromJson(response);
      }
      p.remove(cacheKey).ignore();
      return null;
    } catch (e) {
      debugPrint('[Cache] Error fetching pairing $pairingId: $e');
    }

    final cachedStr = p.getString(cacheKey);
    if (cachedStr != null) {
      return Pairing.fromJson(jsonDecode(cachedStr));
    }
    return null;
  }

  Stream<Pairing?> watchPairingCode(String code) {
    return client
        .from('pairings')
        .stream(primaryKey: ['id'])
        .eq('pairing_code', code.toUpperCase())
        .map((data) => data.isEmpty ? null : Pairing.fromJson(data.first));
  }

  // ────────────────────────────────────────────────────────────────────────────
  // MESSAGES
  // ────────────────────────────────────────────────────────────────────────────

  Future<Message> sendMessage({
    required String pairingId,
    String messageType = 'text',
    String? content,
    String? mediaUrl,
    Map<String, dynamic>? metadata,
    String? replyToId,
  }) async {
    if (currentUserId == null) {
      throw Exception('User must be logged in to send messages');
    }
    final message = Message(
      id: '',
      pairingId: pairingId,
      senderId: currentUserId!,
      messageType: messageType,
      content: content,
      mediaUrl: mediaUrl,
      metadata: metadata ?? {},
      replyToId: replyToId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final toInsert = message.toJson();
    // Encrypt message content end-to-end before it ever reaches the server.
    toInsert['content'] = await EncryptionService.instance.encryptForPairing(
      pairingId,
      message.content,
    );
    final response = await client
        .from('messages')
        .insert(toInsert)
        .select()
        .single();
    return _decryptMessage(Message.fromJson(response));
  }

  Future<List<Message>> getMessages(
    String pairingId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final p = await prefs;
    final cacheKey = 'cache_messages_$pairingId';

    try {
      final response = await client
          .from('messages')
          .select()
          .eq('pairing_id', pairingId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1)
          .timeout(const Duration(seconds: 2));

      if (response.isNotEmpty) {
        // We only cache the first page (up to 50) as a quick fallback
        p.setString(cacheKey, jsonEncode(response)).ignore();
      }
      return _decryptMessages(
        pairingId,
        response.map<Message>((json) => Message.fromJson(json)).toList(),
      );
    } catch (e) {
      debugPrint('[Cache] Error fetching messages: $e. Using cache.');
      final cachedStr = p.getString(cacheKey);
      if (cachedStr != null) {
        final List<dynamic> decoded = jsonDecode(cachedStr);
        return _decryptMessages(
          pairingId,
          decoded
              .map((json) => Message.fromJson(json as Map<String, dynamic>))
              .toList(),
        );
      }
    }
    return [];
  }

  Future<void> markMessagesAsRead(String pairingId) async {
    if (currentUserId == null) return;
    await client.rpc(
      'mark_messages_as_read',
      params: {'p_pairing_id': pairingId, 'p_user_id': currentUserId},
    );
  }

  Stream<List<Message>> watchMessages(String pairingId) async* {
    final p = await prefs;
    final cacheKey = 'cache_messages_$pairingId';

    try {
      final cachedStr = p.getString(cacheKey);
      if (cachedStr != null) {
        debugPrint('[Cache] Loading messages from cache...');
        final List<dynamic> decoded = jsonDecode(cachedStr);
        final cachedMessages =
            decoded
                .where(
                  (json) =>
                      json['pairing_id'] == pairingId &&
                      json['is_deleted'] != true,
                )
                .map((json) => Message.fromJson(json as Map<String, dynamic>))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        yield* _decryptMessages(pairingId, cachedMessages)
            .asStream();
      } else {
        debugPrint('[Cache] No cached messages found.');
      }
    } catch (e) {
      debugPrint('[Cache] Error loading messages: $e');
    }

    yield* client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('pairing_id', pairingId)
        .map((data) {
          _throttledCacheWrite(cacheKey, data);
          final messages =
              data
                  .where(
                    (json) =>
                        json['pairing_id'] == pairingId &&
                        json['is_deleted'] != true,
                  )
                  .map<Message>((json) => Message.fromJson(json))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return messages;
        })
        .asyncMap(
          (messages) => _decryptMessages(pairingId, messages),
        );
  }

  Future<void> deleteMessage(String messageId) async {
    await client
        .from('messages')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', messageId);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // MESSAGE REACTIONS
  // ════════════════════════════════════════════════════════════════════════════

  Future<MessageReaction> addReaction({
    required String messageId,
    required String emoji,
  }) async {
    if (currentUserId == null) {
      throw Exception('User must be logged in to add reactions');
    }
    final response = await client
        .from('message_reactions')
        .upsert({
          'message_id': messageId,
          'user_id': currentUserId!,
          'emoji': emoji,
        })
        .select()
        .single();
    return MessageReaction.fromJson(response);
  }

  Future<void> removeReaction({
    required String messageId,
    required String emoji,
  }) async {
    if (currentUserId == null) return;
    await client
        .from('message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', currentUserId!)
        .eq('emoji', emoji);
  }

  Future<List<MessageReaction>> getReactions(String messageId) async {
    final response = await client
        .from('message_reactions')
        .select()
        .eq('message_id', messageId)
        .order('created_at', ascending: true);
    return response
        .map<MessageReaction>((json) => MessageReaction.fromJson(json))
        .toList();
  }

  Stream<List<MessageReaction>> watchReactions(String messageId) {
    return client
        .from('message_reactions')
        .stream(primaryKey: ['id'])
        .map(
          (data) =>
              data
                  .where((json) => json['message_id'] == messageId)
                  .map<MessageReaction>(
                    (json) => MessageReaction.fromJson(json),
                  )
                  .toList()
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        );
  }

  /// A single realtime subscription to the whole reactions table, grouped by
  /// message id. Use one of these per chat instead of one `watchReactions`
  /// per message (which opened N channels and exceeded the client channel
  /// limit on long histories).
  Stream<Map<String, List<MessageReaction>>> watchAllReactions() {
    return client
        .from('message_reactions')
        .stream(primaryKey: ['id'])
        .map((data) {
          final grouped = <String, List<MessageReaction>>{};
          for (final json in data) {
            final reaction = MessageReaction.fromJson(json);
            grouped.putIfAbsent(reaction.messageId, () => []).add(reaction);
          }
          for (final list in grouped.values) {
            list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          }
          return grouped;
        });
  }

  // ════════════════════════════════════════════════════════════════════════════
  // MESSAGE EDITING
  // ════════════════════════════════════════════════════════════════════════════

  Future<Message> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    final msg = await client
        .from('messages')
        .select('pairing_id')
        .eq('id', messageId)
        .maybeSingle()
        .timeout(const Duration(seconds: 2));
    final pairingId = msg?['pairing_id'] as String? ?? '';
    final response = await client
        .from('messages')
        .update({
          'content': await EncryptionService.instance.encryptForPairing(
            pairingId,
            newContent,
          ),
          'edited_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', messageId)
        .select()
        .single();
    return _decryptMessage(Message.fromJson(response));
  }

  Future<void> updateMessageMetadata(
    String messageId,
    Map<String, dynamic> metadata,
  ) async {
    // First get existing metadata to merge
    final current = await client
        .from('messages')
        .select('metadata')
        .eq('id', messageId)
        .single();
    final Map<String, dynamic> existing = Map<String, dynamic>.from(
      current['metadata'] ?? {},
    );
    existing.addAll(metadata);

    await client
        .from('messages')
        .update({'metadata': existing})
        .eq('id', messageId);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // READ RECEIPTS
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> markMessageAsRead(String messageId) async {
    await client
        .from('messages')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', messageId);
  }

  Future<void> markAllMessagesAsRead(String pairingId) async {
    final uid = currentUserId;
    if (uid == null) return;
    await client
        .from('messages')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('pairing_id', pairingId)
        .neq('sender_id', uid)
        .eq('is_read', false);
  }

  Stream<bool> watchMessageReadStatus(String messageId) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('id', messageId)
        .map(
          (rows) => rows.isNotEmpty
              ? (rows.first['is_read'] as bool? ?? false)
              : false,
        );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // TASKS
  // ────────────────────────────────────────────────────────────────────────────

  /// Soft-deletes every message in a thread for BOTH partners (shared clear,
  /// SEC-19). Any UI calling this MUST confirm with the user first.
  Future<void> clearChatThread({
    required String pairingId,
    required String threadId,
  }) async {
    await client.rpc('clear_chat_thread_messages', params: {
      'p_pairing_id': pairingId,
      'p_thread_id': threadId,
    });
  }

  /// Permanently deletes a thread for BOTH partners (SEC-19). The guarded RPC
  /// refuses to hard-delete unless the thread has already been fully cleared,
  /// so live messages can never be destroyed by a single call. Any UI calling
  /// this MUST warn that it removes the thread for both partners.
  Future<void> deleteChatThread({
    required String pairingId,
    required String threadId,
  }) async {
    await client.rpc('delete_chat_thread_messages', params: {
      'p_pairing_id': pairingId,
      'p_thread_id': threadId,
    });
  }

  Future<Task> createTask({
    required String pairingId,
    required String title,
    String? description,
    String priority = 'medium',
    DateTime? dueDate,
    String? assignedTo,
    List<String>? tags,
  }) async {
    if (currentUserId == null) {
      throw Exception('User must be logged in to create tasks');
    }
    final task = Task(
      id: '',
      pairingId: pairingId,
      createdBy: currentUserId!,
      assignedTo: assignedTo,
      title: title,
      description: description,
      priority: priority,
      dueDate: dueDate,
      tags: tags ?? [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final response = await client
        .from('tasks')
        .insert(task.toJson())
        .select()
        .single();
    return Task.fromJson(response);
  }

  Future<List<Task>> getTasks(
    String pairingId, {
    bool includeCompleted = false,
  }) async {
    final p = await prefs;
    final cacheKey = 'cache_tasks_$pairingId';

    try {
      var query = client.from('tasks').select().eq('pairing_id', pairingId);

      if (!includeCompleted) {
        query = query.eq('is_completed', false);
      }

      final response = await query
          .order('position', ascending: true)
          .timeout(const Duration(seconds: 2));

      final tasks = response.map<Task>((json) => Task.fromJson(json)).toList();
      p.setString(cacheKey, jsonEncode(response)).ignore();
      return tasks;
    } catch (e) {
      debugPrint('[Cache] Error fetching tasks: $e');
      final cachedStr = p.getString(cacheKey);
      if (cachedStr != null) {
        debugPrint('[Cache] Loading tasks from cache fallback...');
        final List<dynamic> decoded = jsonDecode(cachedStr);
        return decoded
            .map((json) => Task.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    }
  }

  Future<Task> updateTask(String taskId, Map<String, dynamic> updates) async {
    final response = await client
        .from('tasks')
        .update(updates)
        .eq('id', taskId)
        .select()
        .single();
    return Task.fromJson(response);
  }

  Future<Task> completeTask(String taskId) async {
    if (currentUserId == null) {
      throw Exception('User must be logged in');
    }
    return updateTask(taskId, {
      'is_completed': true,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
      'completed_by': currentUserId,
    });
  }

  Future<void> deleteTask(String taskId) async {
    await client.from('tasks').delete().eq('id', taskId);
  }

  Stream<List<Task>> watchTasks(String pairingId) async* {
    final p = await prefs;
    final cacheKey = 'cache_tasks_$pairingId';

    try {
      final cachedStr = p.getString(cacheKey);
      if (cachedStr != null) {
        debugPrint('[Cache] Loading tasks from cache...');
        final List<dynamic> decoded = jsonDecode(cachedStr);
        final cachedTasks =
            decoded
                .where((json) => json['pairing_id'] == pairingId)
                .map((json) => Task.fromJson(json as Map<String, dynamic>))
                .toList()
              ..sort((a, b) => a.position.compareTo(b.position));
        yield cachedTasks;
      } else {
        debugPrint('[Cache] No cached tasks found.');
      }
    } catch (e) {
      debugPrint('[Cache] Error loading tasks: $e');
    }

    yield* client.from('tasks').stream(primaryKey: ['id']).map((data) {
      _throttledCacheWrite(cacheKey, data);
      final tasks =
          data
              .where((json) => json['pairing_id'] == pairingId)
              .map<Task>((json) => Task.fromJson(json))
              .toList()
            ..sort((a, b) => a.position.compareTo(b.position));
      return tasks;
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CALENDAR EVENTS
  // ────────────────────────────────────────────────────────────────────────────

  Future<CalendarEvent> createCalendarEvent({
    required String pairingId,
    required String title,
    String? description,
    String? location,
    required DateTime startTime,
    required DateTime endTime,
    bool allDay = false,
    String color = '#B39DFF',
    List<int>? reminderMinutes,
    Map<String, dynamic>? metadata,
  }) async {
    if (currentUserId == null) {
      throw Exception('User must be logged in');
    }
    final event = CalendarEvent(
      id: '',
      pairingId: pairingId,
      createdBy: currentUserId!,
      title: title,
      description: description,
      location: location,
      startTime: startTime,
      endTime: endTime,
      allDay: allDay,
      color: color,
      reminderMinutes: reminderMinutes ?? [],
      metadata: metadata ?? const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final response = await client
        .from('calendar_events')
        .insert(event.toJson())
        .select()
        .single();
    return CalendarEvent.fromJson(response);
  }

  Future<List<CalendarEvent>> getCalendarEvents(
    String pairingId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final p = await prefs;
    final cacheKey = 'cache_calendar_events_$pairingId';

    try {
      final response = await client
          .from('calendar_events')
          .select()
          .eq('pairing_id', pairingId)
          .gte('start_time', startDate.toUtc().toIso8601String())
          .lte('end_time', endDate.toUtc().toIso8601String())
          .order('start_time', ascending: true)
          .timeout(const Duration(seconds: 2));

      final events = response
          .map<CalendarEvent>((json) => CalendarEvent.fromJson(json))
          .toList();
      // Note: We don't overwrite the full cache here because this is a range query
      // but for simplicity in this app, we'll cache the latest fetched range.
      p.setString(cacheKey, jsonEncode(response)).ignore();
      return events;
    } catch (e) {
      debugPrint('[Cache] Error fetching calendar events: $e');
      final cachedStr = p.getString(cacheKey);
      if (cachedStr != null) {
        debugPrint('[Cache] Loading calendar events from cache...');
        final List<dynamic> decoded = jsonDecode(cachedStr);
        return decoded
            .map((json) => CalendarEvent.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    }
  }

  Future<CalendarEvent> updateCalendarEvent(
    String eventId,
    Map<String, dynamic> updates,
  ) async {
    final response = await client
        .from('calendar_events')
        .update(updates)
        .eq('id', eventId)
        .select()
        .single();
    return CalendarEvent.fromJson(response);
  }

  Future<void> deleteCalendarEvent(String eventId) async {
    await client.from('calendar_events').delete().eq('id', eventId);
  }

  Stream<List<CalendarEvent>> watchCalendarEvents(String pairingId) async* {
    final p = await prefs;
    final cacheKey = 'cache_calendar_events_$pairingId';

    try {
      final cachedStr = p.getString(cacheKey);
      if (cachedStr != null) {
        debugPrint('[Cache] Loading calendar events from cache...');
        final List<dynamic> decoded = jsonDecode(cachedStr);
        final cachedEvents =
            decoded
                .where((json) => json['pairing_id'] == pairingId)
                .map(
                  (json) =>
                      CalendarEvent.fromJson(json as Map<String, dynamic>),
                )
                .toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));
        yield cachedEvents;
      } else {
        debugPrint('[Cache] No cached calendar events found.');
      }
    } catch (e) {
      debugPrint('[Cache] Error loading calendar events: $e');
    }

    yield* client.from('calendar_events').stream(primaryKey: ['id']).map((
      data,
    ) {
      _throttledCacheWrite(cacheKey, data);
      final events =
          data
              .where((json) => json['pairing_id'] == pairingId)
              .map<CalendarEvent>((json) => CalendarEvent.fromJson(json))
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
      return events;
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PERIOD LOGS
  // ───────────────────────────────────────────────────────────────────────────

  Future<PeriodLog> createPeriodLog({
    required String? pairingId,
    required DateTime cycleStartDate,
    int cycleLength = 28,
    int periodLength = 5,
    String? flowLevel,
    List<String>? symptoms,
    String? mood,
    String? notes,
  }) async {
    if (currentUserId == null) {
      throw Exception('User must be logged in');
    }

    final periodLog = PeriodLog(
      id: '',
      userId: currentUserId!,
      pairingId: pairingId,
      cycleStartDate: cycleStartDate,
      cycleLength: cycleLength,
      periodLength: periodLength,
      flowLevel: flowLevel,
      symptoms: symptoms,
      mood: mood,
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final response = await client
        .from('cycle_tracking')
        .insert(periodLog.toJson())
        .select()
        .single();
    return PeriodLog.fromJson(response);
  }

  Future<PeriodLog> updatePeriodLog(
    String periodLogId, {
    DateTime? cycleStartDate,
    int? cycleLength,
    int? periodLength,
    String? flowLevel,
    List<String>? symptoms,
    String? mood,
    String? notes,
  }) async {
    final updates = <String, dynamic>{};
    if (cycleStartDate != null) {
      updates['cycle_start_date'] = cycleStartDate.toIso8601String();
    }
    if (cycleLength != null) {
      updates['cycle_length'] = cycleLength;
    }
    if (periodLength != null) {
      updates['period_length'] = periodLength;
    }
    if (flowLevel != null) {
      updates['flow_level'] = flowLevel;
    }
    if (symptoms != null) {
      updates['symptoms'] = symptoms;
    }
    if (mood != null) {
      updates['mood'] = mood;
    }
    if (notes != null) {
      updates['notes'] = notes;
    }

    final response = await client
        .from('cycle_tracking')
        .update(updates)
        .eq('id', periodLogId)
        .select()
        .single();
    return PeriodLog.fromJson(response);
  }

  Future<List<PeriodLog>> getPeriodLogs(String pairingId) async {
    final p = await prefs;
    final cacheKey = 'cache_period_logs_$pairingId';

    try {
      final response = await client
          .from('cycle_tracking')
          .select()
          .eq('pairing_id', pairingId)
          .order('updated_at', ascending: false)
          .order('cycle_start_date', ascending: false)
          .timeout(const Duration(seconds: 2));

      final logs = response
          .map<PeriodLog>((json) => PeriodLog.fromJson(json))
          .toList();
      p.setString(cacheKey, jsonEncode(response)).ignore();
      return logs;
    } catch (e) {
      debugPrint('[Cache] Error fetching period logs: $e');
      final cachedStr = p.getString(cacheKey);
      if (cachedStr != null) {
        debugPrint('[Cache] Loading period logs from cache...');
        final List<dynamic> decoded = jsonDecode(cachedStr);
        return decoded
            .map((json) => PeriodLog.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    }
  }

  Stream<List<PeriodLog>> watchPeriodLogs(String pairingId) async* {
    final p = await prefs;
    final cacheKey = 'cache_period_logs_$pairingId';

    try {
      final cachedStr = p.getString(cacheKey);
      if (cachedStr != null) {
        debugPrint('[Cache] Loading period logs from cache...');
        final List<dynamic> decoded = jsonDecode(cachedStr);
        final cachedLogs =
            decoded
                .where((json) => json['pairing_id'] == pairingId)
                .map((json) => PeriodLog.fromJson(json as Map<String, dynamic>))
                .toList()
              ..sort((a, b) {
                final updatedCompare = b.updatedAt.compareTo(a.updatedAt);
                if (updatedCompare != 0) return updatedCompare;
                return b.cycleStartDate.compareTo(a.cycleStartDate);
              });
        yield cachedLogs;
      }
    } catch (e) {
      debugPrint('[Cache] Error loading period logs: $e');
    }

    yield* client.from('cycle_tracking').stream(primaryKey: ['id']).map((data) {
      _throttledCacheWrite(cacheKey, data);
      final logs =
          data
              .where((json) => json['pairing_id'] == pairingId)
              .map<PeriodLog>((json) => PeriodLog.fromJson(json))
              .toList()
            ..sort((a, b) {
              final updatedCompare = b.updatedAt.compareTo(a.updatedAt);
              if (updatedCompare != 0) return updatedCompare;
              return b.cycleStartDate.compareTo(a.cycleStartDate);
            });
      return logs;
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  Future<BudgetEntry> createBudgetEntry({
    required String pairingId,
    required String title,
    required double amount,
    required String category,
    String? notes,
    DateTime? transactionDate,
    // null → current user paid; non-null → partner paid
    String? paidByUserId,
  }) async {
    if (currentUserId == null) {
      throw Exception('User must be logged in to create budget entries');
    }

    final creatorUserId = currentUserId!;
    final payerUserId = paidByUserId ?? creatorUserId;

    final payload = <String, dynamic>{
      'pairing_id': pairingId,
      'created_by': creatorUserId,
      'paid_by': payerUserId,
      'title': title,
      'amount': amount,
      'category': category,
      'transaction_date': (transactionDate ?? DateTime.now()).toUtc().toIso8601String(),
      'notes': notes,
      // Budget entries always live inside a pairing, so they are always shared
      // with the partner. The old `pairingId != creatorUserId` expression was
      // always true (a pairing UUID can never equal a user UUID).
      'is_shared': true,
    };

    final response = await client
        .from('budget_transactions')
        .insert(payload)
        .select()
        .single();
    final entry = BudgetEntry.fromJson(response);
    _budgetUpdateController.add(null);
    broadcastBudgetSync(pairingId);
    return entry;
  }

  Future<List<BudgetEntry>> getBudgetEntries(String pairingId) async {
    final response = await client
        .from('budget_transactions')
        .select()
        .eq('pairing_id', pairingId)
        .order('transaction_date', ascending: false)
        .order('updated_at', ascending: false);

    return response
        .map<BudgetEntry>((json) => BudgetEntry.fromJson(json))
        .toList();
  }

  Future<BudgetEntry> updateBudgetEntry(
    String entryId,
    Map<String, dynamic> updates,
  ) async {
    final normalizedUpdates = <String, dynamic>{...updates};
    if (normalizedUpdates.containsKey('paidByUserId')) {
      normalizedUpdates['paid_by'] = normalizedUpdates.remove('paidByUserId');
    }
    if (normalizedUpdates['spent_at'] is DateTime) {
      normalizedUpdates['transaction_date'] =
          (normalizedUpdates['spent_at'] as DateTime).toUtc().toIso8601String();
      normalizedUpdates.remove('spent_at');
    }
    if (normalizedUpdates['transaction_date'] is DateTime) {
      normalizedUpdates['transaction_date'] =
          (normalizedUpdates['transaction_date'] as DateTime)
              .toUtc()
              .toIso8601String();
    }

    final response = await client
        .from('budget_transactions')
        .update(normalizedUpdates)
        .eq('id', entryId)
        .select()
        .single();
    final entry = BudgetEntry.fromJson(response);
    _budgetUpdateController.add(null);
    broadcastBudgetSync(entry.pairingId);
    return entry;
  }

  Future<void> deleteBudgetEntry(String entryId) async {
    try {
      final res = await client
          .from('budget_transactions')
          .select('pairing_id')
          .eq('id', entryId)
          .maybeSingle();
      await client.from('budget_transactions').delete().eq('id', entryId);
      _budgetUpdateController.add(null);
      if (res != null && res['pairing_id'] != null) {
        broadcastBudgetSync(res['pairing_id'] as String);
      }
    } catch (e) {
      debugPrint('[BudgetDelete] $e');
    }
  }

  Stream<List<BudgetEntry>> watchBudgetEntries(String pairingId) {
    final controller = StreamController<List<BudgetEntry>>.broadcast();
    final cacheKey = 'cache_budget_entries_$pairingId';

    Future<void> emitFreshEntries() async {
      try {
        final entries = await getBudgetEntries(pairingId);
        if (!controller.isClosed) {
          controller.add(entries);
          _throttledCacheWrite(
            cacheKey,
            entries.map((e) => e.toJson()).toList(),
          );
        }
      } catch (e) {
        debugPrint('[BudgetWatch] Fetch error: $e');
      }
    }

    // 1. Load initial from cache
    SharedPreferences.getInstance().then((prefs) {
      final cachedStr = prefs.getString(cacheKey);
      if (cachedStr != null && !controller.isClosed) {
        try {
          final List<dynamic> decoded = jsonDecode(cachedStr);
          final cachedEntries =
              decoded
                  .map(
                    (json) =>
                        BudgetEntry.fromJson(json as Map<String, dynamic>),
                  )
                  .toList()
                ..sort(
                  (a, b) => b.transactionDate.compareTo(a.transactionDate),
                );
          controller.add(cachedEntries);
        } catch (_) {}
      }
      emitFreshEntries();
    });

    // 2. Listen to local budget changes
    final localSub = _budgetUpdateController.stream.listen((_) {
      emitFreshEntries();
    });

    // 3. Listen to Realtime database stream
    final dbSub = client
        .from('budget_transactions')
        .stream(primaryKey: ['id'])
        .eq('pairing_id', pairingId)
        .listen(
          (data) {
            final entries =
                data
                    .map<BudgetEntry>((json) => BudgetEntry.fromJson(json))
                    .toList()
                  ..sort(
                    (a, b) => b.transactionDate.compareTo(a.transactionDate),
                  );
            if (!controller.isClosed) {
              controller.add(entries);
              _throttledCacheWrite(cacheKey, data);
            }
          },
          onError: (e) {
            debugPrint('[BudgetWatch] DB Stream error: $e');
          },
        );

    // 4. Instant partner sync arrives via `_budgetUpdateController`, which
    //    `initRealtimeAppUpdates` feeds from the shared `app_updates_*` channel.
    //    (Previously this watcher subscribed its own duplicate channel, causing
    //    duplicate refetch cycles per budget change.)

    controller.onCancel = () {
      localSub.cancel();
      dbSub.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // STORAGE
  // ────────────────────────────────────────────────────────────────────────────

  /// Buckets are private (SEC-14); upload functions return the storage *path*
  /// (e.g. `messages/<pairing>/<file>`) instead of a public URL. Consumers
  /// resolve a short-lived signed URL via [secureMediaUrl] at display time.
  Future<String> uploadAvatar(String userId, String filePath) async {
    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '$userId/$fileName';
    await client.storage.from('avatars').upload(path, File(filePath));
    return 'avatars/$path';
  }

  Future<String> uploadMessageMedia(
    String pairingId,
    String messageId,
    String filePath,
    String fileType,
  ) async {
    final extension = filePath.split('.').last;
    final path = '$pairingId/$messageId.$extension';
    await client.storage
        .from('messages')
        .upload(
          path,
          File(filePath), // ← wrap with File
          fileOptions: FileOptions(contentType: fileType),
        );
    return 'messages/$path';
  }

  Future<String> uploadMemory(
    String pairingId,
    String memoryId,
    String filePath,
  ) async {
    final extension = filePath.split('.').last;
    final path = '$pairingId/$memoryId.$extension';
    await client.storage
        .from('memories')
        .upload(
          path,
          File(filePath), // ← wrap with File
        );
    return 'memories/$path';
  }

  // ── Signed-URL resolution for private media (SEC-14) ──────────────────────

  static const Duration _signedUrlTtl = Duration(hours: 48);
  static final Map<String, ({String url, DateTime expiresAt})>
      _signedUrlCache = {};

  /// Resolves a stored media reference into a URL usable by network-image
  /// widgets. Accepts:
  ///   - a storage path (`avatars/…`, `messages/…`, `memories/…`) → signed URL,
  ///   - a legacy public storage URL (already in the DB) → re-signed,
  ///   - an external URL → returned unchanged,
  ///   - anything else (local file path) → returned unchanged.
  Future<String> secureMediaUrl(String value) async {
    if (value.isEmpty) return value;

    if (!value.startsWith('http')) {
      if (value.startsWith('avatars/') ||
          value.startsWith('messages/') ||
          value.startsWith('memories/')) {
        final bucket = value.substring(0, value.indexOf('/'));
        return _signedUrl(bucket, value);
      }
      return value; // local file path or unknown
    }

    final legacy = _parseLegacyStorageUrl(value);
    if (legacy != null) return _signedUrl(legacy.bucket, legacy.path);
    return value; // external URL
  }

  ({String bucket, String path})? _parseLegacyStorageUrl(String url) {
    final match = RegExp(
      r'^https?://[^/]+/storage/v1/object/public/([^/]+)/(.+)$',
    ).firstMatch(url);
    if (match == null) return null;
    return (bucket: match.group(1)!, path: match.group(2)!);
  }

  Future<String> _signedUrl(String bucket, String path) async {
    final now = DateTime.now();
    final cacheKey = '$bucket/$path';
    final cached = _signedUrlCache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(now)) {
      return cached.url;
    }
    try {
      final url = await client.storage
          .from(bucket)
          .createSignedUrl(path, _signedUrlTtl.inSeconds);
      _signedUrlCache[cacheKey] = (
        url: url,
        expiresAt: now.add(_signedUrlTtl),
      );
      return url;
    } catch (e) {
      debugPrint('[Storage] Signed URL failed for $cacheKey: $e');
      return path;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // TYPING STATUS (Realtime Broadcast)
  // ────────────────────────────────────────────────────────────────────────────

  final Map<String, StreamController<Map<String, dynamic>>> _typingControllers =
      {};
  final Map<String, RealtimeChannel> _typingChannels = {};
  final Map<String, int> _typingRefCounts = {};
  final Map<String, StreamController<Map<String, dynamic>>>
  _chatPresenceControllers = {};
  final Map<String, RealtimeChannel> _chatPresenceChannels = {};

  Stream<Map<String, dynamic>> watchTyping(String pairingId) {
    _typingRefCounts[pairingId] = (_typingRefCounts[pairingId] ?? 0) + 1;
    if (_typingControllers.containsKey(pairingId)) {
      return _typingControllers[pairingId]!.stream;
    }

    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _typingControllers[pairingId] = controller;

    final channel = _getTypingChannel(pairingId);

    channel.onBroadcast(
      event: 'typing',
      callback: (payload) {
        if (!controller.isClosed) {
          controller.add(payload);
        }
      },
    );

    return controller.stream;
  }

  /// Releases one reference to the typing channel for [pairingId]. The channel
  /// and controller are only disposed when every listener has released.
  void releaseTypingChannel(String pairingId) {
    final remaining = (_typingRefCounts[pairingId] ?? 1) - 1;
    if (remaining <= 0) {
      _typingRefCounts.remove(pairingId);
      disposeTypingChannel(pairingId);
    } else {
      _typingRefCounts[pairingId] = remaining;
    }
  }

  RealtimeChannel _getTypingChannel(String pairingId) {
    if (_typingChannels.containsKey(pairingId)) {
      return _typingChannels[pairingId]!;
    }
    final channel = client.channel('typing_$pairingId');
    channel.subscribe();
    _typingChannels[pairingId] = channel;
    return channel;
  }

  void sendTypingStatus(String pairingId, bool isTyping) {
    final channel = _getTypingChannel(pairingId);

    channel.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': currentUserId, 'is_typing': isTyping},
    );
  }

  Stream<Map<String, dynamic>> watchChatPresence(String pairingId) {
    if (_chatPresenceControllers.containsKey(pairingId)) {
      return _chatPresenceControllers[pairingId]!.stream;
    }

    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _chatPresenceControllers[pairingId] = controller;

    final channel = _getChatPresenceChannel(pairingId);
    channel.onBroadcast(
      event: 'presence',
      callback: (payload) {
        if (!controller.isClosed) {
          controller.add(payload);
        }
      },
    );

    return controller.stream;
  }

  RealtimeChannel _getChatPresenceChannel(String pairingId) {
    if (_chatPresenceChannels.containsKey(pairingId)) {
      return _chatPresenceChannels[pairingId]!;
    }
    final channel = client.channel('chat_presence_$pairingId');
    channel.subscribe();
    _chatPresenceChannels[pairingId] = channel;
    return channel;
  }

  void broadcastChatPresence(
    String pairingId, {
    required bool isInChat,
    String? threadId,
  }) {
    if (currentUserId == null) return;
    final channel = _getChatPresenceChannel(pairingId);
    channel.sendBroadcastMessage(
      event: 'presence',
      payload: {
        'user_id': currentUserId,
        'is_in_chat': isInChat,
        'thread_id': threadId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  void disposeChatPresenceChannel(String pairingId) {
    _chatPresenceControllers[pairingId]?.close();
    _chatPresenceControllers.remove(pairingId);
    _chatPresenceChannels[pairingId]?.unsubscribe();
    _chatPresenceChannels.remove(pairingId);
  }

  RealtimeChannel? _appUpdatesChannel;
  String? _lastSubscribedPairingId;
  Timer? _broadcastHeartbeat;
  Future<void>? _appUpdatesInitFuture;

  Future<void> initRealtimeAppUpdates() {
    // Serialize concurrent init calls so a second subscriber can't overwrite
    // `_appUpdatesChannel` while the first channel is still being set up.
    return _appUpdatesInitFuture ??= _doInitRealtimeAppUpdates().whenComplete(
      () {
        _appUpdatesInitFuture = null;
      },
    );
  }

  Future<void> _doInitRealtimeAppUpdates() async {
    final pairing = await getActivePairing();
    if (pairing == null) {
      return;
    }
    final pairingId = pairing.id;

    if (_lastSubscribedPairingId == pairingId && _appUpdatesChannel != null) {
      return;
    }
    _appUpdatesChannel?.unsubscribe();
    _lastSubscribedPairingId = pairingId;

    _appUpdatesChannel = client.channel('app_updates_$pairingId');
    _appUpdatesChannel!.onBroadcast(
      event: 'budget_sync',
      callback: (payload) {
        debugPrint('[Realtime] Budget sync received.');
        _budgetUpdateController.add(null);
      },
    );
    _appUpdatesChannel!.onBroadcast(
      event: 'presence_change',
      callback: (payload) {
        final userId = payload['user_id'] as String?;
        final isOnline = payload['is_online'] as bool? ?? false;
        debugPrint(
          '[Realtime] Presence change received for $userId: isOnline=$isOnline',
        );
        if (userId != null) {
          unawaited(_updateCachedProfilePresence(userId, isOnline));
        }
      },
    );
    _appUpdatesChannel!.subscribe();
  }

  Future<void> _updateCachedProfilePresence(
    String userId,
    bool isOnline,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_profiles_'));
    final now = DateTime.now().toUtc();

    for (final k in keys) {
      final str = prefs.getString(k);
      if (str != null) {
        try {
          final List<dynamic> list = jsonDecode(str);
          bool changed = false;
          Map<String, dynamic>? updatedItem;
          final updated = list.map((item) {
            if (item['id'] == userId) {
              changed = true;
              // Set is_online accurately and update timestamps
              item['is_online'] = isOnline;
              item['updated_at'] = now.toIso8601String();
              if (!isOnline) {
                item['last_seen'] = now.toIso8601String();
              }
              updatedItem = Map<String, dynamic>.from(item as Map);
            }
            return item;
          }).toList();
          if (changed && updatedItem != null) {
            prefs.setString(k, jsonEncode(updated)).ignore();
            final updatedProfile = UserProfile.fromJson(updatedItem!);
            _profileUpdateController.add(updatedProfile);
          }
        } catch (_) {}
      }
    }
  }

  void broadcastPresenceChange({required bool isOnline}) {
    if (currentUserId == null || _appUpdatesChannel == null) return;
    try {
      _appUpdatesChannel!.sendBroadcastMessage(
        event: 'presence_change',
        payload: {
          'user_id': currentUserId,
          'is_online': isOnline,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
      debugPrint(
        '[Realtime] Instant presence broadcast sent: isOnline=$isOnline',
      );
    } catch (e) {
      debugPrint('[Realtime] Presence broadcast error: $e');
    }
  }

  void startBroadcastHeartbeat() {
    _broadcastHeartbeat?.cancel();
    _broadcastHeartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
      broadcastPresenceChange(isOnline: true);
    });
    debugPrint('[Realtime] Broadcast heartbeat started');
  }

  void stopBroadcastHeartbeat() {
    _broadcastHeartbeat?.cancel();
    _broadcastHeartbeat = null;
    debugPrint('[Realtime] Broadcast heartbeat stopped');
  }

  void broadcastBudgetSync(String pairingId) {
    if (_appUpdatesChannel != null && _lastSubscribedPairingId == pairingId) {
      _appUpdatesChannel!.sendBroadcastMessage(
        event: 'budget_sync',
        payload: {'timestamp': DateTime.now().millisecondsSinceEpoch},
      );
      return;
    }
    final channel = client.channel('app_updates_$pairingId');
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        unawaited(
          channel
              .sendBroadcastMessage(
                event: 'budget_sync',
                payload: {'timestamp': DateTime.now().millisecondsSinceEpoch},
              )
              .whenComplete(channel.unsubscribe),
        );
      } else {
        channel.unsubscribe();
      }
    });
  }

  void broadcastPinChange(String pairingId, Map<String, dynamic>? pinnedData) {
    final channel = client.channel('chat_updates_$pairingId');
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        unawaited(
          channel
              .sendBroadcastMessage(event: 'pin_change', payload: pinnedData ?? {})
              .whenComplete(channel.unsubscribe),
        );
      } else {
        channel.unsubscribe();
      }
    });
  }

  Stream<Map<String, dynamic>> watchPinChanges(String pairingId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    final channel = client.channel('chat_updates_$pairingId');
    channel.onBroadcast(
      event: 'pin_change',
      callback: (payload) {
        if (!controller.isClosed) {
          controller.add(payload);
        }
      },
    );
    channel.subscribe();
    controller.onCancel = () {
      channel.unsubscribe();
      controller.close();
    };
    return controller.stream;
  }

  void disposeTypingChannel(String pairingId) {
    _typingControllers[pairingId]?.close();
    _typingControllers.remove(pairingId);
    _typingChannels[pairingId]?.unsubscribe();
    _typingChannels.remove(pairingId);
  }
}
