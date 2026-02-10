import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/placeholder_parser.dart';

void main() {
  const parser = PlaceholderParser();

  group('supportedFormats', () {
    test('supports all unsupported/placeholder formats', () {
      expect(parser.supportedFormats, contains(ImportFormat.divingLogXml));
      expect(parser.supportedFormats, contains(ImportFormat.suuntoSml));
      expect(parser.supportedFormats, contains(ImportFormat.suuntoDm5));
      expect(parser.supportedFormats, contains(ImportFormat.shearwaterDb));
      expect(parser.supportedFormats, contains(ImportFormat.scubapro));
      expect(parser.supportedFormats, contains(ImportFormat.danDl7));
      expect(parser.supportedFormats, contains(ImportFormat.sqlite));
      expect(parser.supportedFormats, contains(ImportFormat.unknown));
    });
  });

  group('parse', () {
    test('returns empty entities', () async {
      final result = await parser.parse(Uint8List(0));
      expect(result.entities, isEmpty);
    });

    test('returns info-level warning', () async {
      final result = await parser.parse(Uint8List(0));
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first.severity, ImportWarningSeverity.info);
    });

    test('includes format name in message', () async {
      final result = await parser.parse(
        Uint8List(0),
        options: const ImportOptions(
          sourceApp: SourceApp.suunto,
          format: ImportFormat.suuntoSml,
        ),
      );
      expect(result.warnings.first.message, contains('SML'));
    });

    test('includes export instructions for known app', () async {
      final result = await parser.parse(
        Uint8List(0),
        options: const ImportOptions(
          sourceApp: SourceApp.suunto,
          format: ImportFormat.suuntoSml,
        ),
      );
      // Suunto should have exportInstructions defined
      const sourceApp = SourceApp.suunto;
      if (sourceApp.exportInstructions != null) {
        expect(
          result.warnings.first.message,
          contains(sourceApp.exportInstructions!),
        );
      }
    });

    test('falls back to generic message for unknown format', () async {
      final result = await parser.parse(
        Uint8List(0),
        options: const ImportOptions(
          sourceApp: SourceApp.generic,
          format: ImportFormat.unknown,
        ),
      );
      expect(result.warnings.first.message, contains('not yet supported'));
    });

    test('handles missing options gracefully', () async {
      final result = await parser.parse(Uint8List(0));
      expect(result.entities, isEmpty);
      expect(result.warnings, isNotEmpty);
    });
  });
}
