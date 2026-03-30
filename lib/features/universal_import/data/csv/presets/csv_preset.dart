// Minimal stub - will be fully implemented in Task 6
import 'package:equatable/equatable.dart';

import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

enum PresetSource { builtIn, userSaved }

enum UnitSystem { metric, imperial }

enum ExpectedTimeFormat { h24, h12, informal }

class PresetFileRole extends Equatable {
  final String roleId;
  final String label;
  final bool required;
  final List<String> signatureHeaders;

  const PresetFileRole({
    required this.roleId,
    required this.label,
    this.required = true,
    required this.signatureHeaders,
  });

  @override
  List<Object?> get props => [roleId, label, required, signatureHeaders];
}

class CsvPreset extends Equatable {
  final String id;
  final String name;
  final PresetSource source;
  final SourceApp? sourceApp;
  final List<String> signatureHeaders;
  final double matchThreshold;
  final List<PresetFileRole> fileRoles;
  final Map<String, FieldMapping> mappings;
  final UnitSystem? expectedUnits;
  final ExpectedTimeFormat? expectedTimeFormat;
  final Set<ImportEntityType> supportedEntities;

  const CsvPreset({
    required this.id,
    required this.name,
    this.source = PresetSource.builtIn,
    this.sourceApp,
    this.signatureHeaders = const [],
    this.matchThreshold = 0.6,
    this.fileRoles = const [],
    this.mappings = const {},
    this.expectedUnits,
    this.expectedTimeFormat,
    this.supportedEntities = const {
      ImportEntityType.dives,
      ImportEntityType.sites,
    },
  });

  bool get isMultiFile => fileRoles.length > 1;
  FieldMapping? get primaryMapping => mappings['primary'];

  @override
  List<Object?> get props => [id, name, source, sourceApp];
}
