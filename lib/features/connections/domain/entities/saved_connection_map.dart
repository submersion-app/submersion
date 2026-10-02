import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';

class SavedConnectionMap extends Equatable {
  const SavedConnectionMap({
    required this.id,
    required this.diverId,
    required this.name,
    required this.spec,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String diverId;
  final String name;
  final MapSpec spec;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Null when [specJson] is not a spec this build understands, so a map
  /// saved by a newer build is hidden rather than dropped.
  static SavedConnectionMap? tryParse({
    required String id,
    required String diverId,
    required String name,
    required String specJson,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(specJson);
    } on FormatException {
      return null;
    }
    final spec = MapSpec.fromJson(decoded);
    if (spec == null) return null;
    return SavedConnectionMap(
      id: id,
      diverId: diverId,
      name: name,
      spec: spec,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  SavedConnectionMap copyWith({String? name, MapSpec? spec, int? sortOrder}) {
    return SavedConnectionMap(
      id: id,
      diverId: diverId,
      name: name ?? this.name,
      spec: spec ?? this.spec,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    spec,
    sortOrder,
    createdAt,
    updatedAt,
  ];
}
