class FriendRequestModel {
  final String id;
  final String userId;
  final String username;
  final String? spotifyDisplayName;

  const FriendRequestModel({
    required this.id,
    required this.userId,
    required this.username,
    this.spotifyDisplayName,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> userData = json;

    if (json.containsKey('sender') && json['sender'] is Map<String, dynamic>) {
      userData = json['sender'] as Map<String, dynamic>;
    } else if (json.containsKey('receiver') &&
        json['receiver'] is Map<String, dynamic>) {
      userData = json['receiver'] as Map<String, dynamic>;
    }

    return FriendRequestModel(
      id: (json['friendshipId'] ?? json['id'])?.toString() ?? '',
      userId: userData['id']?.toString() ?? '',
      username: userData['username']?.toString() ?? 'Usuario',
      spotifyDisplayName: userData['spotifyDisplayName']?.toString(),
    );
  }
}
