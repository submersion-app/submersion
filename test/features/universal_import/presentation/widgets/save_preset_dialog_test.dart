import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/widgets/save_preset_dialog.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

const _testMapping = FieldMapping(
  name: 'Test Mapping',
  columns: [
    ColumnMapping(sourceColumn: 'Date', targetField: 'diveDateTime'),
    ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth'),
  ],
);

const _testHeaders = ['Date', 'Depth', 'Duration', 'Location'];

Widget _buildDialog({
  FieldMapping mapping = _testMapping,
  List<String> csvHeaders = _testHeaders,
  SourceApp? detectedSourceApp,
  Set<ImportEntityType> currentEntityTypes = const {
    ImportEntityType.dives,
    ImportEntityType.sites,
  },
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showDialog<CsvPreset>(
              context: context,
              builder: (_) => SavePresetDialog(
                mapping: mapping,
                csvHeaders: csvHeaders,
                detectedSourceApp: detectedSourceApp,
                currentEntityTypes: currentEntityTypes,
              ),
            ),
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open Dialog'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SavePresetDialog - rendering', () {
    testWidgets('renders dialog title', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDialog());
      await _openDialog(tester);

      expect(find.text('Save as Preset'), findsOneWidget);
    });

    testWidgets('renders Preset Name text field', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDialog());
      await _openDialog(tester);

      expect(find.text('Preset Name'), findsOneWidget);
    });

    testWidgets('renders Source Application dropdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDialog());
      await _openDialog(tester);

      expect(find.text('Source Application'), findsOneWidget);
    });

    testWidgets('renders Entity Types section with chips', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDialog());
      await _openDialog(tester);

      expect(find.text('Entity Types'), findsOneWidget);
      // All entity type chips should be present
      expect(find.text('Dives'), findsOneWidget);
      expect(find.text('Sites'), findsOneWidget);
      expect(find.text('Buddies'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Equipment'), findsOneWidget);
    });

    testWidgets('renders Match Threshold section with slider', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDialog());
      await _openDialog(tester);

      expect(find.text('Match Threshold'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('renders signature headers count from csvHeaders', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDialog(csvHeaders: ['A', 'B', 'C']));
      await _openDialog(tester);

      expect(
        find.text('3 signature headers from current file'),
        findsOneWidget,
      );
    });

    testWidgets('renders Cancel and Save buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDialog());
      await _openDialog(tester);

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });

  group('SavePresetDialog - validation', () {
    testWidgets('Save with empty name shows validation error', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDialog());
      await _openDialog(tester);

      // Tap Save without entering a name
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('Save with whitespace-only name shows validation error', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDialog());
      await _openDialog(tester);

      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
    });
  });

  group('SavePresetDialog - interactions', () {
    testWidgets('Cancel closes the dialog and returns null', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDialog());
      await _openDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('Save as Preset'), findsNothing);
    });

    testWidgets('Save with valid name closes the dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDialog());
      await _openDialog(tester);

      await tester.enterText(find.byType(TextFormField), 'My Custom Preset');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Dialog should be closed after successful save
      expect(find.text('Save as Preset'), findsNothing);
    });

    testWidgets('Dives chip is always present and cannot be deselected', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDialog());
      await _openDialog(tester);

      // Find the Dives FilterChip -- it should be selected and disabled
      final divesChip = find.widgetWithText(FilterChip, 'Dives');
      expect(divesChip, findsOneWidget);
      final chip = tester.widget<FilterChip>(divesChip);
      expect(chip.selected, isTrue);
      // onSelected is null for dives (disabled)
      expect(chip.onSelected, isNull);
    });

    testWidgets('toggling a non-dives entity chip updates its selection', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildDialog(
          currentEntityTypes: {ImportEntityType.dives, ImportEntityType.sites},
        ),
      );
      await _openDialog(tester);

      // Buddies chip should initially be unselected
      final buddiesChip = find.widgetWithText(FilterChip, 'Buddies');
      expect(buddiesChip, findsOneWidget);
      var chip = tester.widget<FilterChip>(buddiesChip);
      expect(chip.selected, isFalse);

      // Tap to select
      await tester.tap(buddiesChip);
      await tester.pumpAndSettle();

      chip = tester.widget<FilterChip>(buddiesChip);
      expect(chip.selected, isTrue);

      // Tap again to deselect
      await tester.tap(buddiesChip);
      await tester.pumpAndSettle();

      chip = tester.widget<FilterChip>(buddiesChip);
      expect(chip.selected, isFalse);
    });

    testWidgets('detectedSourceApp is pre-selected in dropdown', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildDialog(detectedSourceApp: SourceApp.subsurface),
      );
      await _openDialog(tester);

      // The dropdown should show Subsurface as selected
      expect(find.text('Subsurface'), findsOneWidget);
    });
  });
}
