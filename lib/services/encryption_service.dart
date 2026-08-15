import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

/// End-to-end encryption for message content.
///
/// Each user owns an X25519 key pair. The private half stays on the device and
/// never leaves it; the public half is stored in the user's profile
/// preferences (`e2ee_pubkey`) so partners can reach it.
///
/// SEC-15: the private key seed is kept in platform secure storage
/// (Android Keystore / iOS Keychain via `flutter_secure_storage`) instead of
/// plaintext SharedPreferences. Keys written before this change are migrated
/// into secure storage on first load.
///
/// For a given pairing the message AES-256-GCM key is derived from the ECDH
/// shared secret of (own private key, partner public key). Because ECDH is
/// symmetric, both partners derive the same key and can decrypt each other's
/// messages while the server only ever sees ciphertext.
///
/// SEC-15b: partners can compare public-key fingerprints ([myFingerprint] /
/// [partnerFingerprint]) out of band to detect any key swap (MITM).
///
/// Ciphertext uses the envelope `lv1:<b64 nonce>.<b64 ciphertext>.<b64 mac>`.
/// Values that do not start with `lv1:` are treated as legacy plaintext
/// (created before encryption was available, or before both partners had
/// published keys) and returned unchanged.
class EncryptionService {
  EncryptionService._();

  static final EncryptionService instance = EncryptionService._();

  static const String _envelopePrefix = 'lv1:';
  static const String _privKeyPrefKey = 'e2ee_private_key';
  static const String _hkdfInfo = 'lovit-e2ee-v1';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  final X25519 _x25519 = X25519();
  SimpleKeyPair? _keyPair;

  /// pairingId -> derived AES-256 key (cached, never persisted).
  final Map<String, SecretKey> _pairingKeyCache = {};

  /// Returns (creating if needed) this device's X25519 key pair.
  Future<SimpleKeyPair> _loadOrCreateKeyPair() async {
    final cached = _keyPair;
    if (cached != null) return cached;

    final seedB64 = await _readSeed();
    if (seedB64 != null) {
      try {
        final pair = await _x25519.newKeyPairFromSeed(base64Decode(seedB64));
        _keyPair = pair;
        return pair;
      } catch (e) {
        debugPrint('[E2EE] Failed to restore key pair: $e');
      }
    }

    final pair = await _x25519.newKeyPair();
    final seed = await pair.extractPrivateKeyBytes();
    await _secureStorage.write(
      key: _privKeyPrefKey,
      value: base64Encode(seed),
    );
    _keyPair = pair;
    return pair;
  }

  /// Reads the private key seed from secure storage, migrating it from the
  /// legacy plaintext SharedPreferences location (pre-SEC-15) if present.
  Future<String?> _readSeed() async {
    try {
      final stored = await _secureStorage.read(key: _privKeyPrefKey);
      if (stored != null && stored.isNotEmpty) return stored;
    } catch (e) {
      debugPrint('[E2EE] Secure storage read failed: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_privKeyPrefKey);
      if (legacy != null && legacy.isNotEmpty) {
        await _secureStorage.write(key: _privKeyPrefKey, value: legacy);
        await prefs.remove(_privKeyPrefKey);
        return legacy;
      }
    } catch (e) {
      debugPrint('[E2EE] Legacy key migration failed: $e');
    }
    return null;
  }

  /// Base64-encoded public key for this device.
  Future<String> getPublicKeyBase64() async {
    final pair = await _loadOrCreateKeyPair();
    final publicKey = await pair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  /// Ensures a key pair exists and publishes the public key to the user's
  /// profile so partners can derive the shared secret. Safe to call on every
  /// app start; it no-ops when the key is already published.
  Future<void> ensureKeyPairAndUpload() async {
    try {
      final publicKey = await getPublicKeyBase64();
      final profile = await SupabaseService().getMyProfile();
      final existing = profile?.preferences['e2ee_pubkey'];
      if (existing == publicKey) return;
      await SupabaseService().uploadE2eePublicKey(publicKey);
    } catch (e) {
      debugPrint('[E2EE] Public key upload failed: $e');
    }
  }

  /// Derives (and caches) the AES-256 key for [pairingId].
  ///
  /// Returns null when the partner's public key isn't known yet — in which
  /// case callers fall back to legacy plaintext.
  Future<SecretKey?> _derivedKey(
    String pairingId, {
    String? partnerPublicKeyB64,
  }) async {
    final cached = _pairingKeyCache[pairingId];
    if (cached != null) return cached;

    final partnerB64 = partnerPublicKeyB64 ??
        await _partnerPublicKey(pairingId);
    if (partnerB64 == null || partnerB64.isEmpty) return null;

    final pair = await _loadOrCreateKeyPair();
    final partnerPublicKey = SimplePublicKey(
      base64Decode(partnerB64),
      type: KeyPairType.x25519,
    );
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: pair,
      remotePublicKey: partnerPublicKey,
    );

    // HKDF-SHA256 stretches the ECDH output into a 32-byte AES-256 key.
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derived = await hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode(_hkdfInfo),
    );
    _pairingKeyCache[pairingId] = derived;
    return derived;
  }

  /// Reads the partner's public key for [pairingId] from their profile.
  Future<String?> _partnerPublicKey(String pairingId) async {
    try {
      final partner = await SupabaseService().getPartnerProfile(pairingId);
      final pub = partner?.preferences['e2ee_pubkey'];
      return pub is String ? pub : null;
    } catch (e) {
      debugPrint('[E2EE] Could not load partner public key: $e');
      return null;
    }
  }

  /// Encrypts [plaintext] for [pairingId]. Returns the plaintext unchanged
  /// when no shared key exists yet (legacy fallback).
  Future<String> encryptForPairing(
    String pairingId,
    String? plaintext, {
    String? partnerPublicKeyB64,
  }) async {
    if (plaintext == null) return '';
    if (plaintext.isEmpty) return plaintext;
    final key = await _derivedKey(
      pairingId,
      partnerPublicKeyB64: partnerPublicKeyB64,
    );
    if (key == null) return plaintext;

    final aes = AesGcm.with256bits();
    final secretBox = await aes.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: aes.newNonce(),
    );
    return '$_envelopePrefix${base64Encode(secretBox.nonce)}.'
        '${base64Encode(secretBox.cipherText)}.'
        '${base64Encode(secretBox.mac.bytes)}';
  }

  /// Decrypts a message [payload] for [pairingId].
  ///
  /// Returns the payload unchanged when it's not an envelope (legacy
  /// plaintext), or null when an envelope can't be decrypted (e.g. key not
  /// yet available or partner key rotated).
  Future<String?> decryptFromPairing(
    String pairingId,
    String? payload, {
    String? partnerPublicKeyB64,
  }) async {
    if (payload == null || payload.isEmpty) return payload;
    if (!payload.startsWith(_envelopePrefix)) return payload;

    final key = await _derivedKey(
      pairingId,
      partnerPublicKeyB64: partnerPublicKeyB64,
    );
    if (key == null) {
      debugPrint('[E2EE] No key for $pairingId yet; cannot decrypt');
      return null;
    }

    try {
      final parts = payload.substring(_envelopePrefix.length).split('.');
      if (parts.length != 3) return null;
      final secretBox = SecretBox(
        base64Decode(parts[1]),
        nonce: base64Decode(parts[0]),
        mac: Mac(base64Decode(parts[2])),
      );
      final aes = AesGcm.with256bits();
      final clearBytes = await aes.decrypt(secretBox, secretKey: key);
      return utf8.decode(clearBytes);
    } catch (e) {
      debugPrint('[E2EE] Decrypt failed for $pairingId: $e');
      return null;
    }
  }

  /// SHA-256 fingerprint of this device's public key (4 groups of 8 hex).
  ///
  /// Compare it with [partnerFingerprint] (or out of band with your partner)
  /// to confirm no public key has been swapped, i.e. the channel is not
  /// being MITM'd. Both partners should derive the same shared secret only
  /// when each holds the other's true public key.
  Future<String> myFingerprint() async {
    final publicKey = await getPublicKeyBase64();
    return _fingerprintOf(publicKey);
  }

  /// Fingerprint of the partner's published public key for [pairingId], or
  /// null when the partner hasn't published a key yet.
  Future<String?> partnerFingerprint(String pairingId) async {
    try {
      final partner = await SupabaseService().getPartnerProfile(pairingId);
      final pub = partner?.preferences['e2ee_pubkey'];
      if (pub is! String || pub.isEmpty) return null;
      return _fingerprintOf(pub);
    } catch (e) {
      debugPrint('[E2EE] Could not load partner fingerprint: $e');
      return null;
    }
  }

  Future<String> _fingerprintOf(String publicKeyB64) async {
    final hash = await Sha256().hash(base64Decode(publicKeyB64));
    final hex = hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();
    return [0, 4, 8, 12].map((i) => hex.substring(i, i + 8)).join('  ');
  }

  /// Clears in-memory key material (used on logout / user switch).
  Future<void> resetForUser() async {
    _keyPair = null;
    _pairingKeyCache.clear();
  }
}
