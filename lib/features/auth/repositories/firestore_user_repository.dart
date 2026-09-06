import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import 'i_user_repository.dart';

/// Production implementation of [IUserRepository] backed by Cloud Firestore.
class FirestoreUserRepository implements IUserRepository {
  FirestoreUserRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _customFirestore = firestore,
        _customAuth = auth;

  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    // Defense-in-depth: Verify authenticated session matches target profile UID
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw StateError('Cannot save profile: Unauthenticated session.');
    }
    if (currentUser.uid != profile.uid) {
      throw StateError('Security violation: Cannot modify profile for another UID.');
    }

    // Input sanitization and bounds enforcement
    if (profile.displayName.trim().isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
    }
    if (profile.displayName.length > 32) {
      throw ArgumentError('Display name exceeds maximum length of 32 characters.');
    }
    if (profile.about.length > 90) {
      throw ArgumentError('About exceeds maximum length of 90 characters.');
    }
    if (profile.publicKey.isEmpty) {
      throw ArgumentError('Public key must not be empty.');
    }

    final docRef = _usersCollection.doc(profile.uid);
    final docSnapshot = await docRef.get();

    final data = profile.toMap();
    if (!docSnapshot.exists) {
      // First-time creation sets the initial creation timestamp
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(data, SetOptions(merge: true));
  }

  @override
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromMap(doc.data()!, uid);
  }

  @override
  Stream<UserProfile?> watchUserProfile(String uid) {
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserProfile.fromMap(snapshot.data()!, uid);
    });
  }
}
