class NodeModel {
  final String id;
  final String label;
  final double posX;
  final double posY;
  final String status;
  final int bpm;
  final String songTitle;
  final String artist;

  NodeModel({
    required this.id,
    required this.label,
    required this.posX,
    required this.posY,
    this.status = 'IDLE',
    this.bpm = 0,
    this.songTitle = '',
    this.artist = '',
  });

  NodeModel copyWith({
    String? id,
    String? label,
    double? posX,
    double? posY,
    String? status,
    int? bpm,
    String? songTitle,
    String? artist,
  }) {
    return NodeModel(
      id: id ?? this.id,
      label: label ?? this.label,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      status: status ?? this.status,
      bpm: bpm ?? this.bpm,
      songTitle: songTitle ?? this.songTitle,
      artist: artist ?? this.artist,
    );
  }
}