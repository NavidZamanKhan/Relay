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
  });

  final String uid;
  final String phoneNumber;
  final String displayName;
  final String about;
  final String publicKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile copyWith({
    String? uid,
    String? phoneNumber,
    String? displayName,
    String? about,
    String? publicKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      about: about ?? this.about,
      publicKey: publicKey ?? this.publicKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
      'updatedAt': FieldValue.serverTimestamp(),
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
      ];
}
