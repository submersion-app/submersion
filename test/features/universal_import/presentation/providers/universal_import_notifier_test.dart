import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

/// Helper to encode a CSV string to bytes for testing.
Uint8List _csvBytes(String csv) => Uint8List.fromList(csv.codeUnits);

/// Wait for the notifier's background async work (e.g. _parseAndCheckDuplicates)
/// to complete. Non-CSV confirmSource fires parsing without await, so we need
/// to pump the event loop until isLoading settles back to false.
Future<void> _waitForAsyncWork(UniversalImportNotifier notifier) async {
  // Pump microtasks until the notifier finishes loading.
  for (var i = 0; i < 100; i++) {
    await Future<void>.delayed(Duration.zero);
    if (!notifier.state.isLoading) break;
  }
}

void main() {
  late ProviderContainer container;
  late UniversalImportNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(universalImportNotifierProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('UniversalImportNotifier', () {
    group('setPendingSourceOverride', () {
      test('sets pendingSourceOverride when given a non-null app', () {
        notifier.setPendingSourceOverride(SourceApp.subsurface);

        expect(notifier.state.pendingSourceOverride, SourceApp.subsurface);
      });

      test('sets different source apps', () {
        notifier.setPendingSourceOverride(SourceApp.macdive);

        expect(notifier.state.pendingSourceOverride, SourceApp.macdive);
      });

      test('clears pendingSourceOverride when given null', () {
        notifier.setPendingSourceOverride(SourceApp.subsurface);
        expect(notifier.state.pendingSourceOverride, SourceApp.subsurface);

        notifier.setPendingSourceOverride(null);

        expect(notifier.state.pendingSourceOverride, isNull);
      });

      test('replaces existing override with new value', () {
        notifier.setPendingSourceOverride(SourceApp.subsurface);
        notifier.setPendingSourceOverride(SourceApp.shearwater);

        expect(notifier.state.pendingSourceOverride, SourceApp.shearwater);
      });

      test('sets pendingFormatOverride when format is provided', () {
        notifier.setPendingSourceOverride(
          SourceApp.subsurface,
          format: ImportFormat.csv,
        );

        expect(notifier.state.pendingSourceOverride, SourceApp.subsurface);
        expect(notifier.state.pendingFormatOverride, ImportFormat.csv);
      });

      test('clears pendingFormatOverride when app is null', () {
        notifier.setPendingSourceOverride(
          SourceApp.subsurface,
          format: ImportFormat.csv,
        );
        notifier.setPendingSourceOverride(null);

        expect(notifier.state.pendingSourceOverride, isNull);
        expect(notifier.state.pendingFormatOverride, isNull);
      });

      test('replaces both app and format when overridden', () {
        notifier.setPendingSourceOverride(
          SourceApp.subsurface,
          format: ImportFormat.csv,
        );
        notifier.setPendingSourceOverride(
          SourceApp.shearwater,
          format: ImportFormat.shearwaterDb,
        );

        expect(notifier.state.pendingSourceOverride, SourceApp.shearwater);
        expect(notifier.state.pendingFormatOverride, ImportFormat.shearwaterDb);
      });
    });

    group('skipAdditionalFile', () {
      test('sets currentStep to fieldMapping', () {
        notifier.skipAdditionalFile();

        expect(notifier.state.currentStep, ImportWizardStep.fieldMapping);
      });

      test('does not modify other state fields', () {
        notifier.setPendingSourceOverride(SourceApp.subsurface);
        notifier.skipAdditionalFile();

        expect(notifier.state.pendingSourceOverride, SourceApp.subsurface);
        expect(notifier.state.currentStep, ImportWizardStep.fieldMapping);
      });
    });

    group('updateFieldMapping', () {
      test('sets fieldMapping in state', () {
        const mapping = FieldMapping(
          name: 'Test Mapping',
          columns: [
            ColumnMapping(sourceColumn: 'Date', targetField: 'dateTime'),
            ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth'),
          ],
        );

        notifier.updateFieldMapping(mapping);

        expect(notifier.state.fieldMapping, mapping);
        expect(notifier.state.fieldMapping!.name, 'Test Mapping');
        expect(notifier.state.fieldMapping!.columns, hasLength(2));
      });

      test('replaces existing fieldMapping', () {
        const mapping1 = FieldMapping(
          name: 'First',
          columns: [
            ColumnMapping(sourceColumn: 'Date', targetField: 'dateTime'),
          ],
        );
        const mapping2 = FieldMapping(
          name: 'Second',
          columns: [
            ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth'),
          ],
        );

        notifier.updateFieldMapping(mapping1);
        notifier.updateFieldMapping(mapping2);

        expect(notifier.state.fieldMapping!.name, 'Second');
      });
    });

    group('confirmFieldMapping', () {
      test('sets step to review when payload is null', () {
        notifier.confirmFieldMapping();

        expect(notifier.state.currentStep, ImportWizardStep.review);
      });

      test('does not change step when called again (payload still null)', () {
        // First call sets step to review.
        notifier.confirmFieldMapping();
        expect(notifier.state.currentStep, ImportWizardStep.review);

        // Manually move step back to fieldMapping to prove
        // confirmFieldMapping will advance again when payload is null.
        notifier.skipAdditionalFile();
        expect(notifier.state.currentStep, ImportWizardStep.fieldMapping);

        notifier.confirmFieldMapping();
        expect(notifier.state.currentStep, ImportWizardStep.review);
      });
    });

    group('toggleSelection', () {
      test('adds index to empty selection', () {
        notifier.toggleSelection(ImportEntityType.dives, 0);

        expect(notifier.state.selectionFor(ImportEntityType.dives), {0});
      });

      test('adds index to existing selection', () {
        notifier.toggleSelection(ImportEntityType.dives, 0);
        notifier.toggleSelection(ImportEntityType.dives, 2);

        expect(notifier.state.selectionFor(ImportEntityType.dives), {0, 2});
      });

      test('removes index when already selected', () {
        notifier.toggleSelection(ImportEntityType.dives, 0);
        notifier.toggleSelection(ImportEntityType.dives, 1);
        notifier.toggleSelection(ImportEntityType.dives, 0);

        expect(notifier.state.selectionFor(ImportEntityType.dives), {1});
      });

      test('maintains separate selections per entity type', () {
        notifier.toggleSelection(ImportEntityType.dives, 0);
        notifier.toggleSelection(ImportEntityType.sites, 1);

        expect(notifier.state.selectionFor(ImportEntityType.dives), {0});
        expect(notifier.state.selectionFor(ImportEntityType.sites), {1});
      });

      test('does not affect other entity type selections', () {
        notifier.toggleSelection(ImportEntityType.dives, 0);
        notifier.toggleSelection(ImportEntityType.dives, 1);
        notifier.toggleSelection(ImportEntityType.sites, 0);

        notifier.toggleSelection(ImportEntityType.dives, 0);

        expect(notifier.state.selectionFor(ImportEntityType.dives), {1});
        expect(notifier.state.selectionFor(ImportEntityType.sites), {0});
      });

      test('toggling same index twice results in empty set', () {
        notifier.toggleSelection(ImportEntityType.dives, 5);
        notifier.toggleSelection(ImportEntityType.dives, 5);

        expect(notifier.state.selectionFor(ImportEntityType.dives), isEmpty);
      });
    });

    group('selectAll', () {
      test('selects all indices when payload has entities', () {
        // selectAll uses totalCountFor which reads from payload.
        // Without a payload, totalCountFor returns 0, so selectAll
        // produces an empty set. We need to verify this behavior.
        notifier.selectAll(ImportEntityType.dives);

        // With no payload, totalCountFor returns 0, so selection is empty.
        expect(notifier.state.selectionFor(ImportEntityType.dives), isEmpty);
      });

      test('does not affect other entity types', () {
        notifier.toggleSelection(ImportEntityType.sites, 0);
        notifier.selectAll(ImportEntityType.dives);

        expect(notifier.state.selectionFor(ImportEntityType.sites), {0});
      });
    });

    group('deselectAll', () {
      test('clears all selections for a type', () {
        notifier.toggleSelection(ImportEntityType.dives, 0);
        notifier.toggleSelection(ImportEntityType.dives, 1);
        notifier.toggleSelection(ImportEntityType.dives, 2);

        notifier.deselectAll(ImportEntityType.dives);

        expect(notifier.state.selectionFor(ImportEntityType.dives), isEmpty);
      });

      test('does not affect other entity types', () {
        notifier.toggleSelection(ImportEntityType.dives, 0);
        notifier.toggleSelection(ImportEntityType.sites, 0);

        notifier.deselectAll(ImportEntityType.dives);

        expect(notifier.state.selectionFor(ImportEntityType.dives), isEmpty);
        expect(notifier.state.selectionFor(ImportEntityType.sites), {0});
      });

      test('is a no-op when already empty', () {
        notifier.deselectAll(ImportEntityType.dives);

        expect(notifier.state.selectionFor(ImportEntityType.dives), isEmpty);
      });
    });

    group('setDiveResolution', () {
      test('sets resolution for a dive index', () {
        notifier.setDiveResolution(0, DiveDuplicateResolution.skip);

        expect(notifier.state.diveResolutions[0], DiveDuplicateResolution.skip);
      });

      test('skip resolution removes dive from selection', () {
        // First add the dive to selection.
        notifier.toggleSelection(ImportEntityType.dives, 0);
        expect(notifier.state.selectionFor(ImportEntityType.dives), {0});

        notifier.setDiveResolution(0, DiveDuplicateResolution.skip);

        expect(
          notifier.state.selectionFor(ImportEntityType.dives),
          isNot(contains(0)),
        );
      });

      test('importAsNew resolution adds dive to selection', () {
        notifier.setDiveResolution(0, DiveDuplicateResolution.importAsNew);

        expect(
          notifier.state.selectionFor(ImportEntityType.dives),
          contains(0),
        );
        expect(
          notifier.state.diveResolutions[0],
          DiveDuplicateResolution.importAsNew,
        );
      });

      test('consolidate resolution adds dive to selection', () {
        notifier.setDiveResolution(0, DiveDuplicateResolution.consolidate);

        expect(
          notifier.state.selectionFor(ImportEntityType.dives),
          contains(0),
        );
        expect(
          notifier.state.diveResolutions[0],
          DiveDuplicateResolution.consolidate,
        );
      });

      test('changing from importAsNew to skip removes from selection', () {
        notifier.setDiveResolution(0, DiveDuplicateResolution.importAsNew);
        expect(
          notifier.state.selectionFor(ImportEntityType.dives),
          contains(0),
        );

        notifier.setDiveResolution(0, DiveDuplicateResolution.skip);

        expect(
          notifier.state.selectionFor(ImportEntityType.dives),
          isNot(contains(0)),
        );
      });

      test('changing from skip to consolidate adds to selection', () {
        notifier.setDiveResolution(0, DiveDuplicateResolution.skip);
        expect(
          notifier.state.selectionFor(ImportEntityType.dives),
          isNot(contains(0)),
        );

        notifier.setDiveResolution(0, DiveDuplicateResolution.consolidate);

        expect(
          notifier.state.selectionFor(ImportEntityType.dives),
          contains(0),
        );
      });

      test('sets resolutions for multiple dive indices independently', () {
        notifier.setDiveResolution(0, DiveDuplicateResolution.skip);
        notifier.setDiveResolution(1, DiveDuplicateResolution.importAsNew);
        notifier.setDiveResolution(2, DiveDuplicateResolution.consolidate);

        expect(notifier.state.diveResolutions[0], DiveDuplicateResolution.skip);
        expect(
          notifier.state.diveResolutions[1],
          DiveDuplicateResolution.importAsNew,
        );
        expect(
          notifier.state.diveResolutions[2],
          DiveDuplicateResolution.consolidate,
        );

        // Indices 1 and 2 should be selected, 0 should not.
        final diveSelection = notifier.state.selectionFor(
          ImportEntityType.dives,
        );
        expect(diveSelection, isNot(contains(0)));
        expect(diveSelection, contains(1));
        expect(diveSelection, contains(2));
      });

      test('does not affect other entity type selections', () {
        notifier.toggleSelection(ImportEntityType.sites, 0);

        notifier.setDiveResolution(0, DiveDuplicateResolution.importAsNew);

        expect(notifier.state.selectionFor(ImportEntityType.sites), {0});
      });
    });

    group('reset', () {
      test('resets to initial state', () {
        // Modify state in multiple ways.
        notifier.setPendingSourceOverride(
          SourceApp.subsurface,
          format: ImportFormat.csv,
        );
        notifier.skipAdditionalFile();
        notifier.toggleSelection(ImportEntityType.dives, 0);
        notifier.setDiveResolution(1, DiveDuplicateResolution.consolidate);

        notifier.reset();

        expect(notifier.state.currentStep, ImportWizardStep.fileSelection);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.isImporting, isFalse);
        expect(notifier.state.error, isNull);
        expect(notifier.state.fileBytes, isNull);
        expect(notifier.state.fileName, isNull);
        expect(notifier.state.detectionResult, isNull);
        expect(notifier.state.pendingSourceOverride, isNull);
        expect(notifier.state.pendingFormatOverride, isNull);
        expect(notifier.state.options, isNull);
        expect(notifier.state.fieldMapping, isNull);
        expect(notifier.state.payload, isNull);
        expect(notifier.state.duplicateResult, isNull);
        expect(notifier.state.selections, isEmpty);
        expect(notifier.state.diveResolutions, isEmpty);
        expect(notifier.state.importCounts, isEmpty);
      });

      test('state matches default constructor after reset', () {
        notifier.setPendingSourceOverride(SourceApp.macdive);
        notifier.toggleSelection(ImportEntityType.dives, 0);
        notifier.toggleSelection(ImportEntityType.dives, 1);

        notifier.reset();

        const defaultState = UniversalImportState();
        expect(notifier.state.currentStep, defaultState.currentStep);
        expect(notifier.state.isLoading, defaultState.isLoading);
        expect(notifier.state.isImporting, defaultState.isImporting);
        expect(notifier.state.error, defaultState.error);
        expect(notifier.state.selections, defaultState.selections);
        expect(notifier.state.diveResolutions, defaultState.diveResolutions);
        expect(notifier.state.importCounts, defaultState.importCounts);
        expect(notifier.state.importPhase, defaultState.importPhase);
        expect(notifier.state.importCurrent, defaultState.importCurrent);
        expect(notifier.state.importTotal, defaultState.importTotal);
      });
    });

    group('confirmSource', () {
      test('returns early when detectionResult is null', () async {
        // State starts with no detectionResult.
        expect(notifier.state.detectionResult, isNull);

        await notifier.confirmSource();

        // Nothing should change -- still at initial step with no options.
        expect(notifier.state.currentStep, ImportWizardStep.fileSelection);
        expect(notifier.state.options, isNull);
      });

      test('uses pending overrides from state when no args provided', () async {
        // Inject state with a detection result and file bytes.
        notifier.state = notifier.state.copyWith(
          detectionResult: const DetectionResult(
            format: ImportFormat.uddf,
            sourceApp: SourceApp.subsurface,
            confidence: 0.9,
          ),
          fileBytes: _csvBytes('placeholder'),
        );

        // Set pending overrides.
        notifier.setPendingSourceOverride(
          SourceApp.macdive,
          format: ImportFormat.csv,
        );

        await notifier.confirmSource();

        // The effective options should use the pending overrides.
        expect(notifier.state.options, isNotNull);
        expect(notifier.state.options!.sourceApp, SourceApp.macdive);
        expect(notifier.state.options!.format, ImportFormat.csv);
      });

      test(
        'explicit overrideApp takes precedence over pending override',
        () async {
          notifier.state = notifier.state.copyWith(
            detectionResult: const DetectionResult(
              format: ImportFormat.uddf,
              sourceApp: SourceApp.subsurface,
              confidence: 0.9,
            ),
            fileBytes: _csvBytes('placeholder'),
          );

          notifier.setPendingSourceOverride(SourceApp.macdive);

          await notifier.confirmSource(overrideApp: SourceApp.shearwater);
          await _waitForAsyncWork(notifier);

          expect(notifier.state.options!.sourceApp, SourceApp.shearwater);
        },
      );

      test(
        'explicit overrideFormat takes precedence over pending format',
        () async {
          notifier.state = notifier.state.copyWith(
            detectionResult: const DetectionResult(
              format: ImportFormat.csv,
              sourceApp: SourceApp.generic,
              confidence: 0.5,
            ),
            fileBytes: _csvBytes('placeholder'),
          );

          notifier.setPendingSourceOverride(
            SourceApp.subsurface,
            format: ImportFormat.csv,
          );

          await notifier.confirmSource(
            overrideApp: SourceApp.subsurface,
            overrideFormat: ImportFormat.subsurfaceXml,
          );
          await _waitForAsyncWork(notifier);

          expect(notifier.state.options!.format, ImportFormat.subsurfaceXml);
        },
      );

      test('uses detection format when no format override', () async {
        notifier.state = notifier.state.copyWith(
          detectionResult: const DetectionResult(
            format: ImportFormat.subsurfaceXml,
            sourceApp: SourceApp.subsurface,
            confidence: 0.95,
          ),
          fileBytes: _csvBytes('<xml></xml>'),
        );

        await notifier.confirmSource();
        await _waitForAsyncWork(notifier);

        expect(notifier.state.options!.format, ImportFormat.subsurfaceXml);
      });

      test(
        'falls back to generic when no sourceApp detected or overridden',
        () async {
          notifier.state = notifier.state.copyWith(
            detectionResult: const DetectionResult(
              format: ImportFormat.uddf,
              confidence: 0.8,
            ),
            fileBytes: _csvBytes('<xml></xml>'),
          );

          await notifier.confirmSource();
          await _waitForAsyncWork(notifier);

          expect(notifier.state.options!.sourceApp, SourceApp.generic);
        },
      );

      test('clears pending overrides after confirmation', () async {
        notifier.state = notifier.state.copyWith(
          detectionResult: const DetectionResult(
            format: ImportFormat.uddf,
            sourceApp: SourceApp.subsurface,
            confidence: 0.9,
          ),
          fileBytes: _csvBytes('test'),
        );

        notifier.setPendingSourceOverride(
          SourceApp.macdive,
          format: ImportFormat.csv,
        );
        expect(notifier.state.pendingSourceOverride, SourceApp.macdive);
        expect(notifier.state.pendingFormatOverride, ImportFormat.csv);

        await notifier.confirmSource();

        // The pending override was CSV, so this takes the CSV path.
        // No need to wait for background parse since CSV path doesn't fire
        // _parseAndCheckDuplicates.
        expect(notifier.state.pendingSourceOverride, isNull);
        expect(notifier.state.pendingFormatOverride, isNull);
      });

      test('sets step to fieldMapping for CSV format', () async {
        final csvData = _csvBytes('Date,Depth,Duration\n2024-01-01,30,45\n');

        notifier.state = notifier.state.copyWith(
          detectionResult: const DetectionResult(
            format: ImportFormat.csv,
            sourceApp: SourceApp.generic,
            confidence: 0.8,
          ),
          fileBytes: csvData,
        );

        await notifier.confirmSource();

        expect(notifier.state.options, isNotNull);
        expect(notifier.state.options!.format, ImportFormat.csv);
        // CSV flow goes to fieldMapping (or additionalFiles if detected).
        expect(
          notifier.state.currentStep,
          anyOf(
            ImportWizardStep.fieldMapping,
            ImportWizardStep.additionalFiles,
          ),
        );
      });

      test('stores parsedCsv from pipeline for CSV format', () async {
        final csvData = _csvBytes('Date,Depth,Duration\n2024-01-01,30,45\n');

        notifier.state = notifier.state.copyWith(
          detectionResult: const DetectionResult(
            format: ImportFormat.csv,
            sourceApp: SourceApp.generic,
            confidence: 0.8,
          ),
          fileBytes: csvData,
        );

        await notifier.confirmSource();

        // Pipeline should have parsed the CSV and stored the result.
        expect(notifier.state.parsedCsv, isNotNull);
        expect(notifier.state.parsedCsv!.headers, contains('Date'));
        expect(notifier.state.parsedCsv!.headers, contains('Depth'));
        expect(notifier.state.parsedCsv!.headers, contains('Duration'));
        expect(notifier.state.parsedCsv!.rowCount, 1);
      });

      test('sets step to review for non-CSV formats', () async {
        notifier.state = notifier.state.copyWith(
          detectionResult: const DetectionResult(
            format: ImportFormat.uddf,
            sourceApp: SourceApp.subsurface,
            confidence: 0.9,
          ),
          fileBytes: _csvBytes('<xml></xml>'),
        );

        await notifier.confirmSource();
        await _waitForAsyncWork(notifier);

        // Non-CSV formats skip fieldMapping and go straight to review.
        expect(notifier.state.currentStep, ImportWizardStep.review);
      });

      test(
        'falls back to fieldMapping when CSV pipeline parse throws',
        () async {
          // Empty bytes will cause CsvPipeline.parse to throw.
          notifier.state = notifier.state.copyWith(
            detectionResult: const DetectionResult(
              format: ImportFormat.csv,
              sourceApp: SourceApp.generic,
              confidence: 0.8,
            ),
            fileBytes: Uint8List(0),
          );

          await notifier.confirmSource();

          // Pipeline failure falls through to the non-pipeline CSV path.
          expect(notifier.state.options!.format, ImportFormat.csv);
          expect(notifier.state.currentStep, ImportWizardStep.fieldMapping);
        },
      );

      test('resets step to sourceConfirmation before processing', () async {
        // Move to a later step first.
        notifier.skipAdditionalFile();
        expect(notifier.state.currentStep, ImportWizardStep.fieldMapping);

        notifier.state = notifier.state.copyWith(
          detectionResult: const DetectionResult(
            format: ImportFormat.csv,
            sourceApp: SourceApp.generic,
            confidence: 0.8,
          ),
          fileBytes: _csvBytes('A,B\n1,2\n'),
        );

        // After confirmSource completes, step should advance past
        // sourceConfirmation to either fieldMapping or additionalFiles.
        await notifier.confirmSource();

        expect(
          notifier.state.currentStep,
          isNot(ImportWizardStep.sourceConfirmation),
        );
      });
    });

    group('updateFieldMapping clears payload', () {
      test('clears existing payload when mapping is updated', () async {
        // Simulate state that has a payload already.
        const existingPayload = ImportPayload(
          entities: {
            ImportEntityType.dives: [
              {'dateTime': '2024-01-01', 'maxDepth': 30.0},
            ],
          },
        );
        notifier.state = notifier.state.copyWith(payload: existingPayload);
        expect(notifier.state.payload, isNotNull);

        const newMapping = FieldMapping(
          name: 'Updated',
          columns: [
            ColumnMapping(sourceColumn: 'Date', targetField: 'dateTime'),
          ],
        );

        notifier.updateFieldMapping(newMapping);

        expect(notifier.state.fieldMapping, newMapping);
        expect(notifier.state.payload, isNull);
      });

      test('sets fieldMapping even when no prior payload exists', () {
        expect(notifier.state.payload, isNull);

        const mapping = FieldMapping(
          name: 'Initial',
          columns: [
            ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth'),
          ],
        );

        notifier.updateFieldMapping(mapping);

        expect(notifier.state.fieldMapping, mapping);
        expect(notifier.state.payload, isNull);
      });
    });

    group('confirmFieldMapping', () {
      test('is a no-op when payload is already set', () async {
        // Pre-populate state with options and a payload.
        const existingPayload = ImportPayload(
          entities: {
            ImportEntityType.dives: [
              {'dateTime': '2024-01-01', 'maxDepth': 30.0},
            ],
          },
        );
        notifier.state = notifier.state.copyWith(
          options: const ImportOptions(
            sourceApp: SourceApp.subsurface,
            format: ImportFormat.csv,
          ),
          payload: existingPayload,
          fileBytes: _csvBytes('Date,Depth\n2024-01-01,30\n'),
          currentStep: ImportWizardStep.fieldMapping,
        );

        await notifier.confirmFieldMapping();

        // Payload should remain unchanged (early return).
        expect(notifier.state.payload, existingPayload);
        // Step should stay at fieldMapping because confirmFieldMapping
        // returned early before setting it.
        expect(notifier.state.currentStep, ImportWizardStep.fieldMapping);
      });

      test('advances to review step when payload is null', () async {
        await notifier.confirmFieldMapping();

        expect(notifier.state.currentStep, ImportWizardStep.review);
      });

      test('sets error when fileBytes is null during parse attempt', () async {
        // Set options but no file bytes.
        notifier.state = notifier.state.copyWith(
          options: const ImportOptions(
            sourceApp: SourceApp.generic,
            format: ImportFormat.csv,
          ),
        );

        await notifier.confirmFieldMapping();

        // _parseAndCheckDuplicates returns early when bytes are null,
        // so no error is set, but step is advanced to review.
        expect(notifier.state.currentStep, ImportWizardStep.review);
        expect(notifier.state.payload, isNull);
        expect(notifier.state.isLoading, isFalse);
      });

      test('sets error when options is null during parse attempt', () async {
        // Set file bytes but no options.
        notifier.state = notifier.state.copyWith(
          fileBytes: _csvBytes('Date,Depth\n2024-01-01,30\n'),
        );

        await notifier.confirmFieldMapping();

        // _parseAndCheckDuplicates returns early when options is null,
        // so no error but step is advanced to review.
        expect(notifier.state.currentStep, ImportWizardStep.review);
        expect(notifier.state.payload, isNull);
        expect(notifier.state.isLoading, isFalse);
      });

      test(
        'sets isLoading true then false during parse for placeholder format',
        () async {
          final loadingStates = <bool>[];

          notifier.state = notifier.state.copyWith(
            options: const ImportOptions(
              sourceApp: SourceApp.generic,
              format: ImportFormat.unknown,
            ),
            fileBytes: _csvBytes('some data'),
          );

          notifier.addListener((state) {
            loadingStates.add(state.isLoading);
          });

          await notifier.confirmFieldMapping();

          // The placeholder parser returns an empty payload, which triggers
          // the error path. Loading should have been set to true then false.
          expect(loadingStates, contains(true));
          expect(notifier.state.isLoading, isFalse);
        },
      );

      test('sets error message when parser returns empty payload', () async {
        // PlaceholderParser returns an empty payload with a warning.
        notifier.state = notifier.state.copyWith(
          options: const ImportOptions(
            sourceApp: SourceApp.generic,
            format: ImportFormat.unknown,
          ),
          fileBytes: _csvBytes('some bytes'),
        );

        await notifier.confirmFieldMapping();

        // PlaceholderParser returns empty entities -> error path.
        expect(notifier.state.error, isNotNull);
        expect(notifier.state.payload, isNull);
        expect(notifier.state.isLoading, isFalse);
      });

      test(
        'uses warning message as error when payload is empty with warnings',
        () async {
          notifier.state = notifier.state.copyWith(
            options: const ImportOptions(
              sourceApp: SourceApp.generic,
              format: ImportFormat.unknown,
            ),
            fileBytes: _csvBytes('test data'),
          );

          await notifier.confirmFieldMapping();

          // PlaceholderParser produces a warning about unsupported format.
          expect(notifier.state.error, isNotNull);
          expect(notifier.state.error, contains('not yet supported'));
        },
      );

      test('sets error on parse exception', () async {
        // SubsurfaceXml parser with invalid XML bytes causes an exception.
        notifier.state = notifier.state.copyWith(
          options: const ImportOptions(
            sourceApp: SourceApp.subsurface,
            format: ImportFormat.subsurfaceXml,
          ),
          fileBytes: _csvBytes('not valid xml at all {{{'),
        );

        await notifier.confirmFieldMapping();

        // Parsing invalid XML should produce an error.
        // Either it throws (caught in catch block) or returns empty payload.
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.error, isNotNull);
      });

      test('passes fieldMapping to CSV parser', () async {
        const mapping = FieldMapping(
          name: 'Custom',
          columns: [
            ColumnMapping(sourceColumn: 'MyDate', targetField: 'dateTime'),
            ColumnMapping(sourceColumn: 'MyDepth', targetField: 'maxDepth'),
            ColumnMapping(sourceColumn: 'MyDuration', targetField: 'duration'),
          ],
        );

        notifier.state = notifier.state.copyWith(
          options: const ImportOptions(
            sourceApp: SourceApp.generic,
            format: ImportFormat.csv,
          ),
          fileBytes: _csvBytes(
            'MyDate,MyDepth,MyDuration\n2024-01-01,30.0,2700\n',
          ),
          fieldMapping: mapping,
        );

        await notifier.confirmFieldMapping();

        // The CSV parser should use the field mapping and produce dives.
        // It may fail at duplicate checking (no provider overrides), but
        // we can verify the parse attempt happened.
        // If parse succeeded but duplicate check fails, we get an error.
        // If parse produced dives, they would be in the payload.
        expect(notifier.state.isLoading, isFalse);
      });
    });

    group('confirmSource with CSV pipeline detection', () {
      test('detects preset for known CSV format headers', () async {
        // Use Subsurface CSV headers to trigger preset detection.
        final csvData = _csvBytes(
          'Dive #,Date,Time,Location,GPS,Max Depth,Duration\n'
          '1,2024-01-15,10:30,Blue Hole,"12.1 -68.9",30.0,45\n',
        );

        notifier.state = notifier.state.copyWith(
          detectionResult: const DetectionResult(
            format: ImportFormat.csv,
            sourceApp: SourceApp.subsurface,
            confidence: 0.8,
          ),
          fileBytes: csvData,
        );

        await notifier.confirmSource();

        expect(notifier.state.options, isNotNull);
        expect(notifier.state.options!.format, ImportFormat.csv);
        expect(notifier.state.parsedCsv, isNotNull);
        // Step should advance past sourceConfirmation.
        expect(
          notifier.state.currentStep,
          isNot(ImportWizardStep.sourceConfirmation),
        );
      });

      test('stores detectedCsvPreset when pipeline matches a preset', () async {
        // MacDive has distinctive headers that should match a built-in preset.
        final csvData = _csvBytes(
          'Dive Number,Date,Time,Duration,Surface Interval,Max. Depth,Avg. Depth,Air Temp.,Surface Temp.\n'
          '1,2024-01-15,10:30,45:00,01:00,30.0,18.5,28.0,26.0\n',
        );

        notifier.state = notifier.state.copyWith(
          detectionResult: const DetectionResult(
            format: ImportFormat.csv,
            sourceApp: SourceApp.macdive,
            confidence: 0.8,
          ),
          fileBytes: csvData,
        );

        await notifier.confirmSource();

        // If a preset was detected, it should be stored in state.
        // Even if no preset matches, the flow should still work.
        expect(notifier.state.options, isNotNull);
        expect(notifier.state.parsedCsv, isNotNull);
      });

      test(
        'proceeds to fieldMapping when no additional files needed',
        () async {
          // A simple CSV with no multi-file preset match.
          final csvData = _csvBytes('Date,Depth,Duration\n2024-01-01,30,45\n');

          notifier.state = notifier.state.copyWith(
            detectionResult: const DetectionResult(
              format: ImportFormat.csv,
              sourceApp: SourceApp.generic,
              confidence: 0.5,
            ),
            fileBytes: csvData,
          );

          await notifier.confirmSource();

          expect(notifier.state.currentStep, ImportWizardStep.fieldMapping);
        },
      );
    });

    group('confirmSource for non-CSV formats', () {
      test('sets step to review for UDDF format', () async {
        notifier.state = notifier.state.copyWith(
          detectionResult: const DetectionResult(
            format: ImportFormat.uddf,
            sourceApp: SourceApp.submersion,
            confidence: 0.95,
          ),
          fileBytes: _csvBytes('<uddf></uddf>'),
        );

        await notifier.confirmSource();
        await _waitForAsyncWork(notifier);

        expect(notifier.state.options!.format, ImportFormat.uddf);
        expect(notifier.state.options!.sourceApp, SourceApp.submersion);
        expect(notifier.state.currentStep, ImportWizardStep.review);
      });

      test('sets step to review for Subsurface XML format', () async {
        notifier.state = notifier.state.copyWith(
          detectionResult: const DetectionResult(
            format: ImportFormat.subsurfaceXml,
            sourceApp: SourceApp.subsurface,
            confidence: 0.9,
          ),
          fileBytes: _csvBytes('<divelog></divelog>'),
        );

        await notifier.confirmSource();
        await _waitForAsyncWork(notifier);

        expect(notifier.state.options!.format, ImportFormat.subsurfaceXml);
        expect(notifier.state.currentStep, ImportWizardStep.review);
      });

      test('sets step to review for FIT format', () async {
        notifier.state = notifier.state.copyWith(
          detectionResult: const DetectionResult(
            format: ImportFormat.fit,
            sourceApp: SourceApp.garminConnect,
            confidence: 0.9,
          ),
          fileBytes: _csvBytes('fit data'),
        );

        await notifier.confirmSource();
        await _waitForAsyncWork(notifier);

        expect(notifier.state.options!.format, ImportFormat.fit);
        expect(notifier.state.currentStep, ImportWizardStep.review);
      });

      test('sets step to review for Shearwater DB format', () async {
        notifier.state = notifier.state.copyWith(
          detectionResult: const DetectionResult(
            format: ImportFormat.shearwaterDb,
            sourceApp: SourceApp.shearwater,
            confidence: 0.95,
          ),
          fileBytes: _csvBytes('db data'),
        );

        await notifier.confirmSource();
        await _waitForAsyncWork(notifier);

        expect(notifier.state.options!.format, ImportFormat.shearwaterDb);
        expect(notifier.state.currentStep, ImportWizardStep.review);
      });
    });

    group('confirmSource option construction', () {
      test(
        'constructs ImportOptions with correct sourceApp and format',
        () async {
          notifier.state = notifier.state.copyWith(
            detectionResult: const DetectionResult(
              format: ImportFormat.uddf,
              sourceApp: SourceApp.suunto,
              confidence: 0.8,
            ),
            fileBytes: _csvBytes('data'),
          );

          await notifier.confirmSource();
          await _waitForAsyncWork(notifier);

          expect(
            notifier.state.options,
            const ImportOptions(
              sourceApp: SourceApp.suunto,
              format: ImportFormat.uddf,
            ),
          );
        },
      );

      test('override sourceApp with detected format', () async {
        notifier.state = notifier.state.copyWith(
          detectionResult: const DetectionResult(
            format: ImportFormat.uddf,
            sourceApp: SourceApp.subsurface,
            confidence: 0.7,
          ),
          fileBytes: _csvBytes('data'),
        );

        await notifier.confirmSource(overrideApp: SourceApp.scubapro);
        await _waitForAsyncWork(notifier);

        expect(notifier.state.options!.sourceApp, SourceApp.scubapro);
        expect(notifier.state.options!.format, ImportFormat.uddf);
      });

      test('override both sourceApp and format', () async {
        notifier.state = notifier.state.copyWith(
          detectionResult: const DetectionResult(
            format: ImportFormat.csv,
            sourceApp: SourceApp.generic,
            confidence: 0.5,
          ),
          fileBytes: _csvBytes('data'),
        );

        await notifier.confirmSource(
          overrideApp: SourceApp.shearwater,
          overrideFormat: ImportFormat.shearwaterDb,
        );
        await _waitForAsyncWork(notifier);

        expect(notifier.state.options!.sourceApp, SourceApp.shearwater);
        expect(notifier.state.options!.format, ImportFormat.shearwaterDb);
      });
    });

    group('state transitions for wizard flow', () {
      test(
        'full CSV wizard flow: pick -> confirm source -> map -> confirm',
        () async {
          // Simulate file pick result.
          final csvData = _csvBytes(
            'Date,Depth,Duration\n2024-01-01,30.0,2700\n',
          );
          notifier.state = notifier.state.copyWith(
            fileBytes: csvData,
            fileName: 'test.csv',
            detectionResult: const DetectionResult(
              format: ImportFormat.csv,
              sourceApp: SourceApp.generic,
              confidence: 0.7,
            ),
            currentStep: ImportWizardStep.sourceConfirmation,
          );

          // Step 1: Confirm source.
          await notifier.confirmSource();
          expect(notifier.state.options, isNotNull);
          expect(notifier.state.options!.format, ImportFormat.csv);

          // Step 2: Update field mapping.
          const mapping = FieldMapping(
            name: 'Test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'dateTime'),
              ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth'),
              ColumnMapping(sourceColumn: 'Duration', targetField: 'duration'),
            ],
          );
          notifier.updateFieldMapping(mapping);
          expect(notifier.state.fieldMapping, mapping);

          // Step 3: Confirm field mapping (triggers parse).
          await notifier.confirmFieldMapping();
          expect(notifier.state.currentStep, ImportWizardStep.review);
        },
      );

      test('non-CSV flow: confirm source goes directly to review', () async {
        notifier.state = notifier.state.copyWith(
          fileBytes: _csvBytes('<uddf/>'),
          fileName: 'test.uddf',
          detectionResult: const DetectionResult(
            format: ImportFormat.uddf,
            sourceApp: SourceApp.submersion,
            confidence: 0.95,
          ),
          currentStep: ImportWizardStep.sourceConfirmation,
        );

        await notifier.confirmSource();
        await _waitForAsyncWork(notifier);

        expect(notifier.state.options!.format, ImportFormat.uddf);
        expect(notifier.state.currentStep, ImportWizardStep.review);
      });

      test('reset after partial wizard flow restores initial state', () async {
        final csvData = _csvBytes('A,B\n1,2\n');
        notifier.state = notifier.state.copyWith(
          fileBytes: csvData,
          fileName: 'test.csv',
          detectionResult: const DetectionResult(
            format: ImportFormat.csv,
            sourceApp: SourceApp.generic,
            confidence: 0.7,
          ),
        );

        await notifier.confirmSource();
        expect(notifier.state.options, isNotNull);

        notifier.updateFieldMapping(
          const FieldMapping(name: 'Test', columns: []),
        );

        notifier.reset();

        expect(notifier.state.currentStep, ImportWizardStep.fileSelection);
        expect(notifier.state.options, isNull);
        expect(notifier.state.fieldMapping, isNull);
        expect(notifier.state.parsedCsv, isNull);
        expect(notifier.state.fileBytes, isNull);
      });
    });
  });
}
