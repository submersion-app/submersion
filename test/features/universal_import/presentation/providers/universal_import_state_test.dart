import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/parsed_csv.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_state.dart';

void main() {
  group('UniversalImportState', () {
    group('copyWith clear flags', () {
      test('clearAdditionalFileBytes sets additionalFileBytes to null', () {
        final state = UniversalImportState(
          additionalFileBytes: Uint8List.fromList([1, 2, 3]),
        );

        final updated = state.copyWith(clearAdditionalFileBytes: true);

        expect(updated.additionalFileBytes, isNull);
      });

      test('clearAdditionalFileName sets additionalFileName to null', () {
        const state = UniversalImportState(additionalFileName: 'profile.csv');

        final updated = state.copyWith(clearAdditionalFileName: true);

        expect(updated.additionalFileName, isNull);
      });

      test('clearPendingSourceOverride sets pendingSourceOverride to null', () {
        const state = UniversalImportState(
          pendingSourceOverride: SourceApp.subsurface,
        );

        final updated = state.copyWith(clearPendingSourceOverride: true);

        expect(updated.pendingSourceOverride, isNull);
      });

      test('clearPendingFormatOverride sets pendingFormatOverride to null', () {
        const state = UniversalImportState(
          pendingFormatOverride: ImportFormat.csv,
        );

        final updated = state.copyWith(clearPendingFormatOverride: true);

        expect(updated.pendingFormatOverride, isNull);
      });

      test('clearDetectedCsvPreset sets detectedCsvPreset to null', () {
        const state = UniversalImportState(
          detectedCsvPreset: CsvPreset(id: 'test', name: 'Test Preset'),
        );

        final updated = state.copyWith(clearDetectedCsvPreset: true);

        expect(updated.detectedCsvPreset, isNull);
      });

      test('clearParsedCsv sets parsedCsv to null', () {
        const state = UniversalImportState(
          parsedCsv: ParsedCsv(
            headers: ['a', 'b'],
            rows: [
              ['1', '2'],
            ],
          ),
        );

        final updated = state.copyWith(clearParsedCsv: true);

        expect(updated.parsedCsv, isNull);
      });
    });

    group('selectionFor', () {
      test('returns correct set for known type', () {
        const state = UniversalImportState(
          selections: {
            ImportEntityType.dives: {0, 1, 2},
            ImportEntityType.sites: {0},
          },
        );

        expect(state.selectionFor(ImportEntityType.dives), {0, 1, 2});
        expect(state.selectionFor(ImportEntityType.sites), {0});
      });

      test('returns empty set for unknown type', () {
        const state = UniversalImportState();

        expect(state.selectionFor(ImportEntityType.dives), isEmpty);
        expect(state.selectionFor(ImportEntityType.equipment), isEmpty);
      });
    });

    group('totalCountFor', () {
      test('returns correct count when payload has entities', () {
        const state = UniversalImportState(
          payload: ImportPayload(
            entities: {
              ImportEntityType.dives: [
                {'dateTime': '2024-01-01'},
                {'dateTime': '2024-01-02'},
                {'dateTime': '2024-01-03'},
              ],
              ImportEntityType.sites: [
                {'name': 'Reef'},
              ],
            },
          ),
        );

        expect(state.totalCountFor(ImportEntityType.dives), 3);
        expect(state.totalCountFor(ImportEntityType.sites), 1);
      });

      test('returns 0 when no payload', () {
        const state = UniversalImportState();

        expect(state.totalCountFor(ImportEntityType.dives), 0);
      });

      test('returns 0 for entity type not in payload', () {
        const state = UniversalImportState(
          payload: ImportPayload(
            entities: {
              ImportEntityType.dives: [
                {'dateTime': '2024-01-01'},
              ],
            },
          ),
        );

        expect(state.totalCountFor(ImportEntityType.equipment), 0);
      });
    });

    group('totalSelected', () {
      test('returns sum of all selections', () {
        const state = UniversalImportState(
          selections: {
            ImportEntityType.dives: {0, 1, 2},
            ImportEntityType.sites: {0, 1},
            ImportEntityType.equipment: {0},
          },
        );

        expect(state.totalSelected, 6);
      });

      test('returns 0 when no selections', () {
        const state = UniversalImportState();

        expect(state.totalSelected, 0);
      });
    });

    group('availableTypes', () {
      test('returns types from payload', () {
        const state = UniversalImportState(
          payload: ImportPayload(
            entities: {
              ImportEntityType.dives: [
                {'dateTime': '2024-01-01'},
              ],
              ImportEntityType.sites: [
                {'name': 'Reef'},
              ],
            },
          ),
        );

        expect(
          state.availableTypes,
          containsAll([ImportEntityType.dives, ImportEntityType.sites]),
        );
      });

      test('returns empty when no payload', () {
        const state = UniversalImportState();

        expect(state.availableTypes, isEmpty);
      });
    });

    group('needsFieldMapping', () {
      test('returns true for CSV format', () {
        const state = UniversalImportState(
          detectionResult: DetectionResult(
            format: ImportFormat.csv,
            confidence: 0.9,
          ),
        );

        expect(state.needsFieldMapping, isTrue);
      });

      test('returns false for non-CSV format', () {
        const state = UniversalImportState(
          detectionResult: DetectionResult(
            format: ImportFormat.uddf,
            confidence: 0.9,
          ),
        );

        expect(state.needsFieldMapping, isFalse);
      });

      test('returns false when no detection result', () {
        const state = UniversalImportState();

        expect(state.needsFieldMapping, isFalse);
      });
    });

    group('importSummary', () {
      test('formats counts correctly for single type', () {
        const state = UniversalImportState(
          importCounts: {ImportEntityType.dives: 5},
        );

        expect(state.importSummary, 'Imported 5 dives');
      });

      test('formats counts correctly for multiple types', () {
        const state = UniversalImportState(
          importCounts: {ImportEntityType.dives: 10, ImportEntityType.sites: 3},
        );

        expect(state.importSummary, contains('10 dives'));
        expect(state.importSummary, contains('3 sites'));
        expect(state.importSummary, startsWith('Imported '));
      });

      test('skips types with zero count', () {
        const state = UniversalImportState(
          importCounts: {
            ImportEntityType.dives: 2,
            ImportEntityType.sites: 0,
            ImportEntityType.equipment: 1,
          },
        );

        final summary = state.importSummary;
        expect(summary, contains('2 dives'));
        expect(summary, contains('1 equipment'));
        expect(summary, isNot(contains('sites')));
      });

      test('returns "No data imported" when empty', () {
        const state = UniversalImportState();

        expect(state.importSummary, 'No data imported');
      });

      test('returns "No data imported" when all counts are zero', () {
        const state = UniversalImportState(
          importCounts: {ImportEntityType.dives: 0, ImportEntityType.sites: 0},
        );

        expect(state.importSummary, 'No data imported');
      });
    });
  });
}
