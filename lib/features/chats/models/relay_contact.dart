import 'package:equatable/equatable.dart';

/// Represents an address book contact or discovered Relay user.
class RelayContact extends Equatable {
  const RelayContact({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    this.publicKey,
    this.about,
    this.avatarUrl,
    this.isRegistered = false,
  });

  final String id;
  final String displayName;
  final String phoneNumber;
  final String? publicKey;
  final String? about;
  final String? avatarUrl;
  final bool isRegistered;

  RelayContact copyWith({
    String? id,
    String? displayName,
    String? phoneNumber,
    String? publicKey,
    String? about,
    String? avatarUrl,
    bool? isRegistered,
  }) =>
      RelayContact(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        publicKey: publicKey ?? this.publicKey,
        about: about ?? this.about,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isRegistered: isRegistered ?? this.isRegistered,
      );

  @override
  List<Object?> get props => [
        id,
        displayName,
        phoneNumber,
        publicKey,
        about,
        avatarUrl,
        isRegistered,
      ];
}
