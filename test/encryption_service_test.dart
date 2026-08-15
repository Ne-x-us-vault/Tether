import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovit/services/encryption_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late X25519 algorithm;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    algorithm = X25519();
  });

  group('EncryptionService round trip', () {
    test('encrypts then decrypts message content with a partner key', () async {
      final partnerPair = await algorithm.newKeyPair();
      final partnerPublic =
          await partnerPair.extractPublicKey();

      final service = EncryptionService.instance;
      final envelope = await service.encryptForPairing(
        'pairing-1',
        'iloveyou',
        partnerPublicKeyB64: base64Encode(partnerPublic.bytes),
      );

      expect(envelope, isNot('iloveyou'));
      expect(envelope, startsWith('lv1:'));

      final decrypted = await service.decryptFromPairing(
        'pairing-1',
        envelope,
        partnerPublicKeyB64: base64Encode(partnerPublic.bytes),
      );
      expect(decrypted, 'iloveyou');
    });

    test('legacy plaintext passes through untouched', () async {
      final partnerPair = await algorithm.newKeyPair();
      final partnerPublic =
          await partnerPair.extractPublicKey();
      final service = EncryptionService.instance;

      final roundTrip = await service.decryptFromPairing(
        'pairing-2',
        'old plaintext message',
        partnerPublicKeyB64: base64Encode(partnerPublic.bytes),
      );
      expect(roundTrip, 'old plaintext message');
    });

    test('falls back to plaintext when partner key is unavailable', () async {
      final service = EncryptionService.instance;
      final envelope = await service.encryptForPairing(
        'pairing-3',
        'no key yet',
      );
      expect(envelope, 'no key yet');
    });

    test('returns null when an envelope cannot be decrypted', () async {
      final service = EncryptionService.instance;
      final decrypted = await service.decryptFromPairing(
        'pairing-4',
        'lv1:AAAAAAAAAAAAAAAAAAAAAA.BBBBBBBBBBBBBBBBBBBBBBBBBB.CCCCCCCCCCCCCCCCCCCCCC',
      );
      expect(decrypted, isNull);
    });

    test('public key is deterministic across sessions (stable key pair)', () async {
      final first = await EncryptionService.instance.getPublicKeyBase64();
      final second = await EncryptionService.instance.getPublicKeyBase64();
      expect(first, second);
      expect(first.length, greaterThan(20));
    });

    test('private key lives in secure storage, not shared preferences', () async {
      await EncryptionService.instance.getPublicKeyBase64();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('e2ee_private_key'), isNull);
    });

    test('legacy SharedPreferences key migrates into secure storage', () async {
      final seed = base64Encode(
        List<int>.generate(32, (i) => i),
      );
      SharedPreferences.setMockInitialValues({
        'e2ee_private_key': seed,
      });
      final service = EncryptionService.instance;
      await service.resetForUser();

      final pub = await service.getPublicKeyBase64();
      expect(pub, isNotEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('e2ee_private_key'), isNull);
    });

    test('myFingerprint is stable and formatted in 4 groups of 8 hex', () async {
      final a = await EncryptionService.instance.myFingerprint();
      final b = await EncryptionService.instance.myFingerprint();
      expect(a, b);
      expect(a.length, greaterThanOrEqualTo(4 * 8 + 2));
      final groups = a.split('  ');
      expect(groups.length, 4);
      expect(
        groups.every((g) => RegExp(r'^[0-9A-F]{8}$').hasMatch(g)),
        isTrue,
      );
    });
  });
}
