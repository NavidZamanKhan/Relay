import '../models/user_profile.dart';

/// Contract for accessing and persisting user profile documents in Cloud Firestore.
abstract interface class IUserRepository {
  /// Persists or updates the user profile document at `users/{profile.uid}`.
  Future<void> saveUserProfile(UserProfile profile);

  /// Retrieves the public user profile document for a given UID.
  Future<UserProfile?> getUserProfile(String uid);

  /// Stream of user profile changes for real-time presence or profile updates.
  Stream<UserProfile?> watchUserProfile(String uid);
}
