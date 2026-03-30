import 'package:equatable/equatable.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

/// Output of the Correlate stage. Entity collections linked by generated IDs.
class CorrelatedPayload extends Equatable {
  final Map<ImportEntityType, List<Map<String, dynamic>>> entities;
  final List<ImportWarning> warnings;
  final Map<String, dynamic> metadata;

  const CorrelatedPayload({
    required this.entities,
    this.warnings = const [],
    this.metadata = const {},
  });

  List<Map<String, dynamic>> entitiesOf(ImportEntityType type) =>
      entities[type] ?? [];

  int get totalEntityCount =>
      entities.values.fold(0, (sum, list) => sum + list.length);

  /// Convert to the universal ImportPayload format.
  ImportPayload toImportPayload() =>
      ImportPayload(entities: entities, warnings: warnings, metadata: metadata);

  @override
  List<Object?> get props => [entities, warnings, metadata];
}
