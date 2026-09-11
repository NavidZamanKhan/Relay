import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Immutable domain model representing a registered Relay user.
class UserProfile extends Equatable {
  const UserProfile({
    required this.uid,
    required this.phoneNumber,
    required this.displayName,
    required this.about,
    required this.publicKey,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
    this.isOnline = false,
    this.lastSeen,
    this.encryptedKeyVault,
    this.fcmToken,
  });

  final String uid;
  final String phoneNumber;
  final String displayName;
  final String about;
  final String publicKey;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? encryptedKeyVault;
  final String? fcmToken;

  UserProfile copyWith({
    String? uid,
    String? phoneNumber,
    String? displayName,
    String? about,
    String? publicKey,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOnline,
    DateTime? lastSeen,
    String? encryptedKeyVault,
    String? fcmToken,
    bool clearFcmToken = false,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      about: about ?? this.about,
      publicKey: publicKey ?? this.publicKey,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      encryptedKeyVault: encryptedKeyVault ?? this.encryptedKeyVault,
      fcmToken: clearFcmToken ? null : (fcmToken ?? this.fcmToken),
    );
  }

  /// Serializes user profile to Firestore document map.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'about': about,
      'publicKey': publicKey,
      'avatarUrl': avatarUrl,
      'isOnline': isOnline,
      'updatedAt': FieldValue.serverTimestamp(),
      if (lastSeen != null) 'lastSeen': Timestamp.fromDate(lastSeen!),
      if (encryptedKeyVault != null) 'encryptedKeyVault': encryptedKeyVault,
      if (fcmToken != null) 'fcmToken': fcmToken,
    };
  }

  /// Deserializes a Firestore document snapshot into a [UserProfile].
  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return UserProfile(
      uid: uid,
      phoneNumber: map['phoneNumber'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      about: map['about'] as String? ?? '',
      publicKey: map['publicKey'] as String? ?? '',
      avatarUrl: (map['avatarUrl'] ?? map['photoUrl']) as String?,
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
      isOnline: (map['isOnline'] as bool?) ?? false,
      lastSeen: parseTimestamp(map['lastSeen']),
      encryptedKeyVault: map['encryptedKeyVault'] as String?,
      fcmToken: map['fcmToken'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        phoneNumber,
        displayName,
        about,
        publicKey,
        avatarUrl,
        createdAt,
        updatedAt,
        isOnline,
        lastSeen,
        encryptedKeyVault,
        fcmToken,
      ];
}
