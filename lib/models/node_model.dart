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

  NodeModel({
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

  factory NodeModel.fromJson(Map<String, dynamic> json) {
    return NodeModel(
      id: json['id']?.toString() ?? '',
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
}
