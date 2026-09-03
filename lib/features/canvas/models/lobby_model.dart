import 'package:flutter/foundation.dart';
import '../../canvas/models/node_model.dart';

/// Data transfer object representing a spatial lobby partition in the application.
/// Encapsulates room metadata, capacity constraints, and active occupant nodes.
@immutable
class LobbyModel {
  final String id;
  final String name;
  final int occupantsCount;
  final int maxCapacity;
  final String createdAt;
  final List<NodeModel> nodes;

  const LobbyModel({
    required this.id,
    required this.name,
    required this.occupantsCount,
    required this.maxCapacity,
    required this.createdAt,
    required this.nodes,
  });

  /// Factory constructor for instantiating a [LobbyModel] from raw JSON payloads.
  /// Guarantees null safety with fallback defaults and type-safe list parsing.
  factory LobbyModel.fromJson(Map<String, dynamic> json) {
    return LobbyModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      occupantsCount: json['occupantsCount'] as int? ?? 0,
      maxCapacity: json['maxCapacity'] as int? ?? 20,
      createdAt: json['createdAt'] as String? ?? '',
      nodes: (json['nodes'] as List<dynamic>?)
              ?.map((item) => NodeModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Converts the model back into a JSON-compatible map structure.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'occupantsCount': occupantsCount,
      'maxCapacity': maxCapacity,
      'createdAt': createdAt,
      'nodes': nodes.map((node) => node.toJson()).toList(),
    };
  }

  /// Creates a copy of this [LobbyModel] with optional updated fields.
  LobbyModel copyWith({
    String? id,
    String? name,
    int? occupantsCount,
    int? maxCapacity,
    String? createdAt,
    List<NodeModel>? nodes,
  }) {
    return LobbyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      occupantsCount: occupantsCount ?? this.occupantsCount,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      createdAt: createdAt ?? this.createdAt,
      nodes: nodes ?? this.nodes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LobbyModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          occupantsCount == other.occupantsCount &&
          maxCapacity == other.maxCapacity &&
          createdAt == other.createdAt &&
          listEquals(nodes, other.nodes);

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      occupantsCount.hashCode ^
      maxCapacity.hashCode ^
      createdAt.hashCode ^
      Object.hashAll(nodes);
}
