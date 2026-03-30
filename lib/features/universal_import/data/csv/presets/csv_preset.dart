import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/services/value_transforms.dart';

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

  // ======================== JSON Serialization ========================

  /// Serializes this preset to a JSON string for user-saved presets.
  String toJson() {
    final mappingsJson = <String, dynamic>{};
    for (final entry in mappings.entries) {
      mappingsJson[entry.key] = _fieldMappingToJson(entry.value);
    }

    final data = <String, dynamic>{
      'id': id,
      'name': name,
      if (sourceApp != null) 'sourceApp': sourceApp!.name,
      'signatureHeaders': signatureHeaders,
      'matchThreshold': matchThreshold,
      'mappings': mappingsJson,
      if (expectedUnits != null) 'expectedUnits': expectedUnits!.name,
      if (expectedTimeFormat != null)
        'expectedTimeFormat': expectedTimeFormat!.name,
      'supportedEntities': supportedEntities.map((e) => e.name).toList(),
    };

    return jsonEncode(data);
  }

  /// Deserializes a preset from a JSON string. Always sets source to
  /// [PresetSource.userSaved].
  factory CsvPreset.fromJson(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    final sourceAppName = data['sourceApp'] as String?;
    final SourceApp? sourceApp = sourceAppName != null
        ? SourceApp.values.firstWhere(
            (e) => e.name == sourceAppName,
            orElse: () => SourceApp.generic,
          )
        : null;

    final expectedUnitsName = data['expectedUnits'] as String?;
    final UnitSystem? expectedUnits = expectedUnitsName != null
        ? UnitSystem.values.firstWhere(
            (e) => e.name == expectedUnitsName,
            orElse: () => UnitSystem.metric,
          )
        : null;

    final expectedTimeFormatName = data['expectedTimeFormat'] as String?;
    final ExpectedTimeFormat? expectedTimeFormat =
        expectedTimeFormatName != null
        ? ExpectedTimeFormat.values.firstWhere(
            (e) => e.name == expectedTimeFormatName,
            orElse: () => ExpectedTimeFormat.h24,
          )
        : null;

    final rawMappings = data['mappings'] as Map<String, dynamic>? ?? {};
    final mappings = <String, FieldMapping>{};
    for (final entry in rawMappings.entries) {
      mappings[entry.key] = _fieldMappingFromJson(
        entry.value as Map<String, dynamic>,
      );
    }

    final rawEntities =
        (data['supportedEntities'] as List<dynamic>?)?.cast<String>() ?? [];
    final supportedEntities = rawEntities
        .map(
          (name) => ImportEntityType.values.firstWhere(
            (e) => e.name == name,
            orElse: () => ImportEntityType.dives,
          ),
        )
        .toSet();

    final rawHeaders =
        (data['signatureHeaders'] as List<dynamic>?)?.cast<String>() ?? [];

    return CsvPreset(
      id: data['id'] as String,
      name: data['name'] as String,
      source: PresetSource.userSaved,
      sourceApp: sourceApp,
      signatureHeaders: rawHeaders,
      matchThreshold: (data['matchThreshold'] as num?)?.toDouble() ?? 0.6,
      mappings: mappings,
      expectedUnits: expectedUnits,
      expectedTimeFormat: expectedTimeFormat,
      supportedEntities: supportedEntities.isEmpty
          ? const {ImportEntityType.dives, ImportEntityType.sites}
          : supportedEntities,
    );
  }

  // ======================== JSON Helpers ========================

  static Map<String, dynamic> _fieldMappingToJson(FieldMapping mapping) {
    return {
      'name': mapping.name,
      if (mapping.sourceApp != null) 'sourceApp': mapping.sourceApp!.name,
      'columns': mapping.columns.map(_columnMappingToJson).toList(),
    };
  }

  static FieldMapping _fieldMappingFromJson(Map<String, dynamic> data) {
    final sourceAppName = data['sourceApp'] as String?;
    final SourceApp? sourceApp = sourceAppName != null
        ? SourceApp.values.firstWhere(
            (e) => e.name == sourceAppName,
            orElse: () => SourceApp.generic,
          )
        : null;

    final rawColumns =
        (data['columns'] as List<dynamic>?)
            ?.map((c) => _columnMappingFromJson(c as Map<String, dynamic>))
            .toList() ??
        [];

    return FieldMapping(
      name: data['name'] as String,
      sourceApp: sourceApp,
      columns: rawColumns,
    );
  }

  static Map<String, dynamic> _columnMappingToJson(ColumnMapping col) {
    return {
      'sourceColumn': col.sourceColumn,
      'targetField': col.targetField,
      if (col.transform != null) 'transform': col.transform!.name,
      if (col.defaultValue != null) 'defaultValue': col.defaultValue,
    };
  }

  static ColumnMapping _columnMappingFromJson(Map<String, dynamic> data) {
    final transformName = data['transform'] as String?;
    final ValueTransform? transform = transformName != null
        ? ValueTransform.values.firstWhere(
            (e) => e.name == transformName,
            orElse: () =>
                throw FormatException('Unknown ValueTransform: $transformName'),
          )
        : null;

    return ColumnMapping(
      sourceColumn: data['sourceColumn'] as String,
      targetField: data['targetField'] as String,
      transform: transform,
      defaultValue: data['defaultValue'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name, source, sourceApp];
}
