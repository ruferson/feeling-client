import 'package:flutter/foundation.dart';

/// Data transfer object representing a spatial node in the canvas.
/// Encapsulates spatial coordinates, audio playback metadata, and client-side elastic deformation states.
@immutable
class NodeModel {
  final String id;
  final String label;
  final double posX; // Screen pixel X or Longitude
  final double posY; // Screen pixel Y or Latitude
  final String status;
  final int bpm;
  final bool bpmEstimated;
  final bool isPlaying;
  final String songTitle;
  final String artist;

  // Visual jelly deformation properties (Local Client Only)
  final double scaleX;
  final double scaleY;
  final double rotationAngle;

  const NodeModel({
    required this.id,
    required this.label,
    required this.posX,
    required this.posY,
    this.status = 'IDLE',
    this.bpm = 0,
    this.bpmEstimated = false,
    this.isPlaying = false,
    this.songTitle = '',
    this.artist = '',
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.rotationAngle = 0.0,
  });

  /// Factory constructor for instantiating a [NodeModel] from raw JSON payloads.
  /// Maps `userId` (or nested `user.id`) as the primary node identifier to guarantee
  /// alignment with `ApiService.currentUserId` across local drag gestures and color mapping.
  factory NodeModel.fromJson(Map<String, dynamic> json) {
    final String extractedUserId =
        (json['userId'] ?? json['user']?['id'] ?? json['id'])?.toString() ?? '';

    return NodeModel(
      id: extractedUserId,
      label: json['label'] ?? json['user']?['username'] ?? 'User',
      posX: (json['posX'] ?? 0.0).toDouble(),
      posY: (json['posY'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'ACTIVE',
      bpm: json['bpm'] ?? 0,
      bpmEstimated: json['bpmEstimated'] == true,
      isPlaying: json['isPlaying'] == true,
      songTitle: json['songTitle'] ?? '',
      artist: json['artist'] ?? '',
    );
  }

  /// Converts the [NodeModel] instance into a JSON-compatible map structure.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': id,
      'label': label,
      'posX': posX,
      'posY': posY,
      'status': status,
      'bpm': bpm,
      'bpmEstimated': bpmEstimated,
      'isPlaying': isPlaying,
      'songTitle': songTitle,
      'artist': artist,
      'user': {
        'id': id,
        'username': label,
      },
    };
  }

  /// Creates a copy of this [NodeModel] with optional updated fields.
  NodeModel copyWith({
    String? id,
    String? label,
    double? posX,
    double? posY,
    String? status,
    int? bpm,
    bool? bpmEstimated,
    bool? isPlaying,
    String? songTitle,
    String? artist,
    double? scaleX,
    double? scaleY,
    double? rotationAngle,
  }) {
    return NodeModel(
      id: id ?? this.id,
      label: label ?? this.label,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      status: status ?? this.status,
      bpm: bpm ?? this.bpm,
      bpmEstimated: bpmEstimated ?? this.bpmEstimated,
      isPlaying: isPlaying ?? this.isPlaying,
      songTitle: songTitle ?? this.songTitle,
      artist: artist ?? this.artist,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotationAngle: rotationAngle ?? this.rotationAngle,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          posX == other.posX &&
          posY == other.posY &&
          status == other.status &&
          bpm == other.bpm &&
          bpmEstimated == other.bpmEstimated &&
          isPlaying == other.isPlaying &&
          songTitle == other.songTitle &&
          artist == other.artist &&
          scaleX == other.scaleX &&
          scaleY == other.scaleY &&
          rotationAngle == other.rotationAngle;

  @override
  int get hashCode =>
      id.hashCode ^
      label.hashCode ^
      posX.hashCode ^
      posY.hashCode ^
      status.hashCode ^
      bpm.hashCode ^
      bpmEstimated.hashCode ^
      isPlaying.hashCode ^
      songTitle.hashCode ^
      artist.hashCode ^
      scaleX.hashCode ^
      scaleY.hashCode ^
      rotationAngle.hashCode;
}
