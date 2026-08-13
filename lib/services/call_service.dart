import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallService {
  CallService._();

  static final CallService instance = CallService._();

  static const String voiceCallType = 'voice_call';
  static const String videoCallType = 'video_call';
  static const String _pendingCallPayloadKey = 'pending_call_payload';

  final JitsiMeet _jitsiMeet = JitsiMeet();
  bool _isJoiningOrActive = false;

  bool isCallNotificationType(String? type) {
    return type == voiceCallType || type == videoCallType;
  }

  Future<void> queuePendingCallPayload(Map<String, dynamic> data) async {
    final normalized = _normalizeCallPayload(data);
    if (normalized == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingCallPayloadKey, jsonEncode(normalized));
    debugPrint('[Call] Queued pending ${normalized['type']} for ${normalized['room_name']}');
  }

  Future<void> consumePendingCallPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingCallPayloadKey);
    if (raw == null || raw.isEmpty) return;
    await prefs.remove(_pendingCallPayloadKey);

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        await handleCallPayload(decoded);
      } else if (decoded is Map) {
        await handleCallPayload(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      debugPrint('[Call] Failed to consume pending payload: $e');
    }
  }

  Future<bool> startOutgoingCall({
    required String roomName,
    required bool isVideo,
    required String displayName,
    String? avatarUrl,
  }) async {
    return _joinCall(
      roomName: roomName,
      isVideo: isVideo,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }

  Future<bool> handleCallPayload(Map<String, dynamic> data) async {
    final normalized = _normalizeCallPayload(data);
    if (normalized == null) return false;

    final roomName = normalized['room_name'] as String?;
    if (roomName == null || roomName.isEmpty) {
      debugPrint('[Call] Ignored payload without room name');
      return false;
    }

    final type = normalized['type'] as String?;
    final isVideo = type == videoCallType;
    final displayName =
        _sanitizeText(normalized['recipient_name'] as String?) ?? 'Lovit User';

    return _joinCall(
      roomName: roomName,
      isVideo: isVideo,
      displayName: displayName,
      avatarUrl: _sanitizeText(normalized['recipient_avatar_url'] as String?),
    );
  }

  Map<String, dynamic>? _normalizeCallPayload(Map<String, dynamic> data) {
    final rawType = _sanitizeText(data['type']?.toString());
    if (!isCallNotificationType(rawType)) return null;

    final roomName =
        _sanitizeText(data['room_name']?.toString()) ??
        _sanitizeText(data['roomName']?.toString());

    if (roomName == null || roomName.isEmpty) return null;

    return {
      'type': rawType,
      'room_name': roomName,
      'pairing_id': _sanitizeText(data['pairing_id']?.toString()),
      'caller_name': _sanitizeText(data['caller_name']?.toString()),
      'caller_avatar_url': _sanitizeText(data['caller_avatar_url']?.toString()),
      'recipient_name': _sanitizeText(data['recipient_name']?.toString()),
      'recipient_avatar_url': _sanitizeText(
        data['recipient_avatar_url']?.toString(),
      ),
    };
  }

  Future<bool> _joinCall({
    required String roomName,
    required bool isVideo,
    required String displayName,
    String? avatarUrl,
  }) async {
    if (_isJoiningOrActive) {
      debugPrint('[Call] Join ignored because another call is active');
      return false;
    }

    final permissionsGranted = await _ensurePermissions(isVideo: isVideo);
    if (!permissionsGranted) {
      debugPrint('[Call] Permissions denied for ${isVideo ? "video" : "voice"} call');
      return false;
    }

    _isJoiningOrActive = true;

    try {
      final options = JitsiMeetConferenceOptions(
        serverURL: 'https://meet.jit.si',
        room: roomName,
        configOverrides: {
          'startWithAudioMuted': false,
          'startWithVideoMuted': !isVideo,
          'startAudioOnly': !isVideo,
          'subject': 'Lovit Call',
          'requireDisplayName': false,
        },
        featureFlags: {
          FeatureFlags.welcomePageEnabled: false,
          FeatureFlags.preJoinPageEnabled: false,
          FeatureFlags.inviteEnabled: false,
          FeatureFlags.meetingNameEnabled: false,
          FeatureFlags.chatEnabled: false,
          FeatureFlags.helpButtonEnabled: false,
          FeatureFlags.pipEnabled: true,
          FeatureFlags.callIntegrationEnabled: true,
          FeatureFlags.audioOnlyButtonEnabled: true,
          FeatureFlags.videoShareEnabled: isVideo,
          FeatureFlags.recordingEnabled: false,
          FeatureFlags.liveStreamingEnabled: false,
          FeatureFlags.toolboxAlwaysVisible: false,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: displayName,
          avatar: avatarUrl,
        ),
      );

      await _jitsiMeet.join(
        options,
        JitsiMeetEventListener(
          conferenceTerminated: (url, error) {
            _isJoiningOrActive = false;
            debugPrint('[Call] Conference terminated: $url error=$error');
          },
          readyToClose: () {
            _isJoiningOrActive = false;
            debugPrint('[Call] Ready to close');
          },
        ),
      );
      debugPrint('[Call] Joined ${isVideo ? "video" : "voice"} call room=$roomName');
      return true;
    } catch (e) {
      _isJoiningOrActive = false;
      debugPrint('[Call] Failed to join room $roomName: $e');
      return false;
    }
  }

  Future<bool> _ensurePermissions({required bool isVideo}) async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) return false;
    if (!isVideo) return true;
    final cameraStatus = await Permission.camera.request();
    return cameraStatus.isGranted;
  }

  String? _sanitizeText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }
}
