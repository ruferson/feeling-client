import 'package:flutter/foundation.dart';

/// Data transfer object representing a friendship record, active friend, or pending request state.
/// Normalizes nested JSON schemas (sender/receiver payloads or mapped friend DTOs) into unified entity models,
/// strictly distinguishing between the unique relationship identifier [friendshipId] and the peer's [userId].
@immutable
class FriendRequestModel {
  final String friendshipId;
  final String userId;
  final String username;
  final String? spotifyDisplayName;
  final Map<String, dynamic>? node;

  const FriendRequestModel({
    required this.friendshipId,
    required this.userId,
    required this.username,
    this.spotifyDisplayName,
    this.node,
  });

  /// Factory constructor for instantiating a [FriendRequestModel] from raw backend JSON payloads.
  /// Polymorphically checks for 'receiver' (outbound) or 'sender' (inbound) relations.
  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> userData = json;
    String resolvedUserId = '';

    if (json.containsKey('receiver') &&
        json['receiver'] is Map<String, dynamic>) {
      userData = json['receiver'] as Map<String, dynamic>;
      resolvedUserId =
          userData['id']?.toString() ?? json['receiverId']?.toString() ?? '';
    } else if (json.containsKey('sender') &&
        json['sender'] is Map<String, dynamic>) {
      userData = json['sender'] as Map<String, dynamic>;
      resolvedUserId =
          userData['id']?.toString() ?? json['senderId']?.toString() ?? '';
    } else {
      resolvedUserId =
          json['userId']?.toString() ??
          json['friendUserId']?.toString() ??
          userData['id']?.toString() ??
          '';
    }

    return FriendRequestModel(
      friendshipId: (json['friendshipId'] ?? json['id'])?.toString() ?? '',
      userId: resolvedUserId,
      username: userData['username']?.toString() ?? 'User',
      spotifyDisplayName: userData['spotifyDisplayName']?.toString(),
      node:
          json['node'] is Map<String, dynamic>
              ? json['node'] as Map<String, dynamic>
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'friendshipId': friendshipId,
      'userId': userId,
      'username': username,
      if (spotifyDisplayName != null) 'spotifyDisplayName': spotifyDisplayName,
      if (node != null) 'node': node,
    };
  }

  FriendRequestModel copyWith({
    String? friendshipId,
    String? userId,
    String? username,
    String? spotifyDisplayName,
    Map<String, dynamic>? node,
  }) {
    return FriendRequestModel(
      friendshipId: friendshipId ?? this.friendshipId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      spotifyDisplayName: spotifyDisplayName ?? this.spotifyDisplayName,
      node: node ?? this.node,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendRequestModel &&
          runtimeType == other.runtimeType &&
          friendshipId == other.friendshipId &&
          userId == other.userId &&
          username == other.username &&
          spotifyDisplayName == other.spotifyDisplayName &&
          node == other.node;

  @override
  int get hashCode =>
      friendshipId.hashCode ^
      userId.hashCode ^
      username.hashCode ^
      spotifyDisplayName.hashCode ^
      (node?.hashCode ?? 0);
}
