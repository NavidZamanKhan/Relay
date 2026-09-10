import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/features/auth/models/user_profile.dart';
import 'package:relay/features/auth/repositories/firestore_user_repository.dart';

class FakeUser extends Fake implements User {
  FakeUser({required this.uid, this.phoneNumber, this.photoURL});
  @override
  final String uid;
  @override
  final String? phoneNumber;
  @override
  final String? photoURL;
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  FakeFirebaseAuth({this.user});
  User? user;

  @override
  User? get currentUser => user;
}

void main() {
  group('UserProfile Model Security & Serialization', () {
    test('serializes to map with server timestamp and clean fields', () {
      const profile = UserProfile(
        uid: 'user_123',
        phoneNumber: '+16505551234',
        displayName: 'Navid',
        about: 'Building Relay.',
        publicKey: 'base64_x25519_key_32bytes_mock',
        encryptedKeyVault: '{"ciphertext":"c123","nonce":"n123","v":1}',
      );

      final map = profile.toMap();
      expect(map['uid'], 'user_123');
      expect(map['phoneNumber'], '+16505551234');
      expect(map['displayName'], 'Navid');
      expect(map['about'], 'Building Relay.');
      expect(map['publicKey'], 'base64_x25519_key_32bytes_mock');
      expect(map['avatarUrl'], isNull);
      expect(map['encryptedKeyVault'], '{"ciphertext":"c123","nonce":"n123","v":1}');
      expect(map['updatedAt'], isA<FieldValue>());
    });

    test('serializes with avatarUrl correctly', () {
      const profile = UserProfile(
        uid: 'user_123',
        phoneNumber: '+16505551234',
        displayName: 'Navid',
        about: 'Building Relay.',
        publicKey: 'pub_key',
        avatarUrl: 'https://firebasestorage.googleapis.com/avatar.jpg',
      );

      final map = profile.toMap();
      expect(map['avatarUrl'], 'https://firebasestorage.googleapis.com/avatar.jpg');
    });

    test('deserializes safely with missing or corrupted fields', () {
      final profile = UserProfile.fromMap(const {
        'displayName': 'Test User',
      }, 'uid_fallback');

      expect(profile.uid, 'uid_fallback');
      expect(profile.displayName, 'Test User');
      expect(profile.about, '');
      expect(profile.phoneNumber, '');
      expect(profile.publicKey, '');
      expect(profile.avatarUrl, isNull);
      expect(profile.encryptedKeyVault, isNull);
      expect(profile.createdAt, isNull);
    });

    test('deserializes avatarUrl from avatarUrl or photoUrl keys', () {
      final p1 = UserProfile.fromMap(const {
        'displayName': 'Alice',
        'avatarUrl': 'https://example.com/alice.jpg',
      }, 'uid_1');
      expect(p1.avatarUrl, 'https://example.com/alice.jpg');

      final p2 = UserProfile.fromMap(const {
        'displayName': 'Bob',
        'photoUrl': 'https://example.com/bob.jpg',
      }, 'uid_2');
      expect(p2.avatarUrl, 'https://example.com/bob.jpg');
    });
  });

  group('FirestoreUserRepository Anti-Spoofing & Input Bounds', () {
    test('rejects profile update when unauthenticated', () async {
      final fakeAuth = FakeFirebaseAuth(user: null);
      final repo = FirestoreUserRepository(auth: fakeAuth);

      const profile = UserProfile(
        uid: 'attacker_uid',
        phoneNumber: '+16505551234',
        displayName: 'Attacker',
        about: '',
        publicKey: 'pub_key',
      );

      expect(
        () => repo.saveUserProfile(profile),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects profile modification when UID does not match authenticated user', () async {
      final fakeAuth = FakeFirebaseAuth(
        user: FakeUser(uid: 'legitimate_user_id'),
      );
      final repo = FirestoreUserRepository(auth: fakeAuth);

      const spoofedProfile = UserProfile(
        uid: 'victim_user_id', // Spoofed target
        phoneNumber: '+16505551234',
        displayName: 'Malicious Overwrite',
        about: '',
        publicKey: 'attacker_pub_key',
      );

      expect(
        () => repo.saveUserProfile(spoofedProfile),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Security violation'),
          ),
        ),
      );
    });

    test('rejects profile when display name exceeds 32 characters', () async {
      final fakeAuth = FakeFirebaseAuth(user: FakeUser(uid: 'valid_user'));
      final repo = FirestoreUserRepository(auth: fakeAuth);

      final oversizedProfile = UserProfile(
        uid: 'valid_user',
        phoneNumber: '+16505551234',
        displayName: 'A' * 33, // 33 characters (exceeds limit)
        about: 'Normal about',
        publicKey: 'valid_key',
      );

      expect(
        () => repo.saveUserProfile(oversizedProfile),
        throwsArgumentError,
      );
    });

    test('rejects profile when public key is empty', () async {
      final fakeAuth = FakeFirebaseAuth(user: FakeUser(uid: 'valid_user'));
      final repo = FirestoreUserRepository(auth: fakeAuth);

      const emptyKeyProfile = UserProfile(
        uid: 'valid_user',
        phoneNumber: '+16505551234',
        displayName: 'Valid Name',
        about: 'Normal about',
        publicKey: '',
      );

      expect(
        () => repo.saveUserProfile(emptyKeyProfile),
        throwsArgumentError,
      );
    });

    test('serializes and deserializes isOnline and lastSeen accurately', () {
      final now = DateTime.utc(2026, 9, 8, 4, 0);
      final profile = UserProfile(
        uid: 'user_pres',
        phoneNumber: '+16505550199',
        displayName: 'Sadman',
        about: 'Active now',
        publicKey: 'KEY',
        isOnline: true,
        lastSeen: now,
      );

      final map = profile.toMap();
      expect(map['isOnline'], isTrue);
      expect(map['lastSeen'], isA<Timestamp>());

      final deserialized = UserProfile.fromMap(map, 'user_pres');
      expect(deserialized.isOnline, isTrue);
      expect(deserialized.lastSeen?.toUtc(), equals(now));
    });

    test('updatePresence safely returns without error when unauthenticated', () async {
      final fakeAuth = FakeFirebaseAuth(user: null);
      final repo = FirestoreUserRepository(auth: fakeAuth);

      await expectLater(
        repo.updatePresence(uid: 'user_123', isOnline: true),
        completes,
      );
    });
  });
}
