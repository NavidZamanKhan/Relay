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
    this.createdAt,
    this.updatedAt,
    this.isOnline = false,
    this.lastSeen,
  });

  final String uid;
  final String phoneNumber;
  final String displayName;
  final String about;
  final String publicKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isOnline;
  final DateTime? lastSeen;

  UserProfile copyWith({
    String? uid,
    String? phoneNumber,
    String? displayName,
    String? about,
    String? publicKey,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      about: about ?? this.about,
      publicKey: publicKey ?? this.publicKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
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
      'isOnline': isOnline,
      'updatedAt': FieldValue.serverTimestamp(),
      if (lastSeen != null) 'lastSeen': Timestamp.fromDate(lastSeen!),
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
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
      isOnline: (map['isOnline'] as bool?) ?? false,
      lastSeen: parseTimestamp(map['lastSeen']),
    );
  }

  @override
  List<Object?> get props => [
        uid,
        phoneNumber,
        displayName,
        about,
        publicKey,
        createdAt,
        updatedAt,
        isOnline,
        lastSeen,
      ];
}
