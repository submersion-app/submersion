import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';

/// Parser adapter for UDDF and Subsurface XML files.
///
/// Wraps [UddfFullImportService] and converts its [UddfImportResult]
/// into the unified [ImportPayload] format. This is the richest parser,
/// capable of producing all 11 entity types from a full Submersion export.
class UddfImportParser implements ImportParser {
  final UddfFullImportService _service;

  UddfImportParser({UddfFullImportService? service})
    : _service = service ?? UddfFullImportService();

  @override
  List<ImportFormat> get supportedFormats => [
    ImportFormat.uddf,
    ImportFormat.subsurfaceXml,
  ];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final content = utf8.decode(fileBytes, allowMalformed: true);

    try {
      final result = await _service.importAllDataFromUddf(content);

      final entities = <ImportEntityType, List<Map<String, dynamic>>>{};

      if (result.dives.isNotEmpty) {
        entities[ImportEntityType.dives] = result.dives;
      }
      if (result.sites.isNotEmpty) {
        entities[ImportEntityType.sites] = result.sites;
      }
      if (result.trips.isNotEmpty) {
        entities[ImportEntityType.trips] = result.trips;
      }
      if (result.equipment.isNotEmpty) {
        entities[ImportEntityType.equipment] = result.equipment;
      }
      if (result.equipmentSets.isNotEmpty) {
        entities[ImportEntityType.equipmentSets] = result.equipmentSets;
      }
      if (result.buddies.isNotEmpty) {
        entities[ImportEntityType.buddies] = result.buddies;
      }
      if (result.diveCenters.isNotEmpty) {
        entities[ImportEntityType.diveCenters] = result.diveCenters;
      }
      if (result.certifications.isNotEmpty) {
        entities[ImportEntityType.certifications] = result.certifications;
      }
      if (result.courses.isNotEmpty) {
        entities[ImportEntityType.courses] = result.courses;
      }
      if (result.tags.isNotEmpty) {
        entities[ImportEntityType.tags] = result.tags;
      }
      if (result.customDiveTypes.isNotEmpty) {
        entities[ImportEntityType.diveTypes] = result.customDiveTypes;
      }

      return ImportPayload(
        entities: entities,
        metadata: {
          'sourceApp': options?.sourceApp.displayName ?? 'UDDF',
          'summary': result.summary,
        },
      );
    } on FormatException catch (e) {
      return ImportPayload(
        entities: const {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Invalid UDDF file: ${e.message}',
          ),
        ],
      );
    }
  }
}
