import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/csv/presets/built_in_presets.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/csv_preset_providers.dart';
import 'package:submersion/features/universal_import/presentation/widgets/select_preset_sheet.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

const _testHeaders = ['Date', 'Time', 'Max Depth', 'Duration'];

CsvPreset _makeUserPreset({
  String id = 'user-preset-1',
  String name = 'My User Preset',
  SourceApp? sourceApp,
  List<String> signatureHeaders = const ['date', 'time', 'max depth'],
  double matchThreshold = 0.3,
}) {
  return CsvPreset(
    id: id,
    name: name,
    source: PresetSource.userSaved,
    sourceApp: sourceApp,
    signatureHeaders: signatureHeaders,
    matchThreshold: matchThreshold,
    supportedEntities: const {ImportEntityType.dives, ImportEntityType.sites},
  );
}

Widget _buildSheet({
  List<String> csvHeaders = _testHeaders,
  List<CsvPreset> userPresets = const [],
}) {
  return ProviderScope(
    overrides: [
      userCsvPresetsProvider.overrideWith((ref) => Future.value(userPresets)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<CsvPreset>(
                context: context,
                isScrollControlled: true,
                builder: (_) => SelectPresetSheet(csvHeaders: csvHeaders),
              ),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Open Sheet'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SelectPresetSheet - rendering', () {
    testWidgets('renders title and built-in presets section', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildSheet());
      await _openSheet(tester);

      expect(find.text('Select Preset'), findsOneWidget);
      expect(find.text('Built-in Presets'), findsOneWidget);
    });

    testWidgets('renders first few built-in preset names', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildSheet());
      await _openSheet(tester);

      // Verify at least the first few built-in presets are rendered.
      // Some may be off-screen in the scrollable list.
      final firstPreset = builtInCsvPresets.first;
      expect(
        find.text(firstPreset.name),
        findsAtLeastNWidgets(1),
        reason: 'Expected to find built-in preset: ${firstPreset.name}',
      );
    });

    testWidgets('does not show Saved Presets section when no user presets', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildSheet(userPresets: []));
      await _openSheet(tester);

      expect(find.text('Saved Presets'), findsNothing);
    });
  });

  group('SelectPresetSheet - user presets', () {
    testWidgets('shows Saved Presets section when user presets exist', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final userPreset = _makeUserPreset(name: 'My Custom Mapping');

      await tester.pumpWidget(_buildSheet(userPresets: [userPreset]));
      await _openSheet(tester);

      expect(find.text('Saved Presets'), findsOneWidget);
      expect(find.text('My Custom Mapping'), findsOneWidget);
    });

    testWidgets('user presets have a delete button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final userPreset = _makeUserPreset();

      await tester.pumpWidget(_buildSheet(userPresets: [userPreset]));
      await _openSheet(tester);

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('built-in presets do not have a delete button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildSheet(userPresets: []));
      await _openSheet(tester);

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('delete button shows confirmation dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final userPreset = _makeUserPreset(name: 'Deletable Preset');

      await tester.pumpWidget(_buildSheet(userPresets: [userPreset]));
      await _openSheet(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete Preset'), findsOneWidget);
      expect(
        find.text('Delete "Deletable Preset"? This cannot be undone.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('canceling delete confirmation dismisses dialog', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final userPreset = _makeUserPreset(name: 'Keep This Preset');

      await tester.pumpWidget(_buildSheet(userPresets: [userPreset]));
      await _openSheet(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Tap Cancel on the confirmation dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Confirmation dialog should be dismissed, preset still visible
      expect(find.text('Delete Preset'), findsNothing);
      expect(find.text('Keep This Preset'), findsOneWidget);
    });

    testWidgets('shows multiple user presets with delete buttons', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final presets = [
        _makeUserPreset(id: 'p1', name: 'Preset Alpha'),
        _makeUserPreset(id: 'p2', name: 'Preset Beta'),
      ];

      await tester.pumpWidget(_buildSheet(userPresets: presets));
      await _openSheet(tester);

      expect(find.text('Preset Alpha'), findsOneWidget);
      expect(find.text('Preset Beta'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    });
  });

  group('SelectPresetSheet - preset card content', () {
    testWidgets('shows match score info for built-in presets', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildSheet());
      await _openSheet(tester);

      // Each built-in preset card should display match information
      // (e.g., "X/Y headers matched (Z%)")
      expect(find.textContaining('headers matched'), findsWidgets);
    });

    testWidgets('shows sourceApp badge when preset has sourceApp', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildSheet());
      await _openSheet(tester);

      // Built-in presets with sourceApp should show their app name as a badge.
      // Subsurface preset has sourceApp set.
      expect(find.text('Subsurface'), findsWidgets);
    });
  });

  group('SelectPresetSheet - selection', () {
    testWidgets('tapping a built-in preset closes the sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildSheet());
      await _openSheet(tester);

      // Tap the first built-in preset by finding the InkWell card.
      // Use .first since the preset name may also appear in the sourceApp badge.
      final firstPresetName = builtInCsvPresets.first.name;
      await tester.tap(find.text(firstPresetName).first);
      await tester.pumpAndSettle();

      // The sheet should be dismissed
      expect(find.text('Select Preset'), findsNothing);
    });

    testWidgets('tapping a user preset closes the sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final userPreset = _makeUserPreset(name: 'Tappable Preset');

      await tester.pumpWidget(_buildSheet(userPresets: [userPreset]));
      await _openSheet(tester);

      await tester.tap(find.text('Tappable Preset'));
      await tester.pumpAndSettle();

      // The sheet should be dismissed
      expect(find.text('Select Preset'), findsNothing);
    });
  });

  group('SelectPresetSheet - loading and error states', () {
    testWidgets('shows loading indicator while presets load', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Use a Completer so the future never resolves during the test
      final completer = Completer<List<CsvPreset>>();
      addTearDown(() {
        if (!completer.isCompleted) completer.complete([]);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userCsvPresetsProvider.overrideWith((ref) => completer.future),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet<CsvPreset>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          const SelectPresetSheet(csvHeaders: _testHeaders),
                    ),
                    child: const Text('Open Sheet'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Sheet'));
      await tester.pump();
      // Only pump once so the future doesn't resolve
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when presets fail to load', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userCsvPresetsProvider.overrideWith(
              (ref) => Future<List<CsvPreset>>.error('DB connection failed'),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet<CsvPreset>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          const SelectPresetSheet(csvHeaders: _testHeaders),
                    ),
                    child: const Text('Open Sheet'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load presets'), findsOneWidget);
    });
  });
}
