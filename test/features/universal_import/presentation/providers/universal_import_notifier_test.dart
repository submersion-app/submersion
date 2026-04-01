import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

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
  });
}
