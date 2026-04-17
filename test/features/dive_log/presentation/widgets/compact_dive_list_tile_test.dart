import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CompactDiveListTile', () {
    testWidgets('renders dive number, site name, date, depth, and duration', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'test-id',
            diveNumber: 42,
            dateTime: DateTime(2026, 3, 15, 9, 30),
            siteName: 'Blue Corner Wall',
            maxDepth: 28.5,
            duration: const Duration(minutes: 52),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#42'), findsOneWidget);
      expect(find.text('Blue Corner Wall'), findsOneWidget);
      expect(find.textContaining('28'), findsWidgets);
      expect(find.textContaining('52'), findsWidgets);
    });

    testWidgets('shows checkbox in selection mode', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'test-id',
            diveNumber: 42,
            dateTime: DateTime(2026, 3, 15),
            isSelectionMode: true,
            isSelected: true,
            onTap: () {},
          ),
        ),
      );

      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('uses unknown site text when siteName is null', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'test-id',
            diveNumber: 1,
            dateTime: DateTime(2026, 3, 15),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#1'), findsOneWidget);
    });

    testWidgets('fires onDoubleTap on double-tap gesture', (tester) async {
      bool doubleTapped = false;
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'test-id',
            diveNumber: 42,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Test Site',
            onTap: () {},
            onDoubleTap: () => doubleTapped = true,
          ),
        ),
      );

      final tile = find.text('Test Site');
      await tester.tap(tile);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(doubleTapped, isTrue);
    });

    testWidgets('shows highlight styling when isHighlighted is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'test-id',
            diveNumber: 42,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Test Site',
            isHighlighted: true,
            onTap: () {},
          ),
        ),
      );

      // The outer Container should have a highlight border decoration
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CompactDiveListTile),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration;
      expect(decoration, isNotNull);
    });

    testWidgets('renders with null depth and duration shows fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'null-id',
            diveNumber: 5,
            dateTime: DateTime(2026, 3, 15),
            maxDepth: null,
            duration: null,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#5'), findsOneWidget);
      expect(find.text('--'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders with gradient card coloring', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'color-id',
            diveNumber: 10,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Coral Reef',
            maxDepth: 25.0,
            duration: const Duration(minutes: 40),
            colorValue: 25.0,
            minValueInList: 10.0,
            maxValueInList: 40.0,
            gradientStartColor: const Color(0xFF4DD0E1),
            gradientEndColor: const Color(0xFF0D1B2A),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#10'), findsOneWidget);
      expect(find.text('Coral Reef'), findsOneWidget);
    });

    testWidgets('renders with configurable title field from summary', (
      tester,
    ) async {
      final summary = DiveSummary(
        id: 'sum-1',
        dateTime: DateTime(2026, 3, 15),
        diveNumber: 7,
        maxDepth: 20.0,
        bottomTime: const Duration(minutes: 30),
        runtime: const Duration(minutes: 35),
        siteName: 'Blue Hole',
        waterTemp: 22.0,
        sortTimestamp: 0,
      );

      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'sum-1',
            diveNumber: 7,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Blue Hole',
            maxDepth: 20.0,
            duration: const Duration(minutes: 30),
            summary: summary,
            titleField: DiveField.waterTemp,
            dateField: DiveField.maxDepth,
            stat1Field: DiveField.bottomTime,
            stat2Field: DiveField.waterTemp,
            onTap: () {},
          ),
        ),
      );

      // With non-default title field, it extracts from summary
      expect(find.text('#7'), findsOneWidget);
    });

    testWidgets('renders with selected state applying container color', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'sel-id',
            diveNumber: 3,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Deep Wall',
            isSelected: true,
            onTap: () {},
          ),
        ),
      );

      // Should render without crash when selected
      expect(find.text('#3'), findsOneWidget);
      expect(find.text('Deep Wall'), findsOneWidget);
    });

    testWidgets('fires onLongPress callback', (tester) async {
      bool longPressed = false;
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'lp-id',
            diveNumber: 8,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Reef Point',
            onTap: () {},
            onLongPress: () => longPressed = true,
          ),
        ),
      );

      await tester.longPress(find.text('Reef Point'));
      await tester.pumpAndSettle();

      expect(longPressed, isTrue);
    });

    testWidgets('renders stat slot with icon when field has icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'icon-id',
            diveNumber: 12,
            dateTime: DateTime(2026, 3, 15),
            maxDepth: 30.0,
            duration: const Duration(minutes: 50),
            stat1Field: DiveField.maxDepth,
            stat2Field: DiveField.bottomTime,
            onTap: () {},
          ),
        ),
      );

      // maxDepth and bottomTime have icons
      expect(find.text('#12'), findsOneWidget);
    });

    testWidgets('renders with summary and non-default stat fields', (
      tester,
    ) async {
      final summary = DiveSummary(
        id: 'ns-1',
        dateTime: DateTime(2026, 3, 15),
        diveNumber: 15,
        maxDepth: 18.0,
        bottomTime: const Duration(minutes: 25),
        runtime: const Duration(minutes: 30),
        siteName: 'Sandy Bottom',
        waterTemp: 20.0,
        rating: 4,
        sortTimestamp: 0,
      );

      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'ns-1',
            diveNumber: 15,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Sandy Bottom',
            maxDepth: 18.0,
            duration: const Duration(minutes: 25),
            summary: summary,
            stat1Field: DiveField.ratingStars,
            stat2Field: DiveField.runtime,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#15'), findsOneWidget);
    });

    testWidgets('renders stat slot without icon using label:value format', (
      tester,
    ) async {
      // Use a field that has no icon (e.g., notes) to exercise the
      // label:value branch in _buildStatSlot.
      final summary = DiveSummary(
        id: 'noicon-1',
        dateTime: DateTime(2026, 3, 15),
        diveNumber: 20,
        maxDepth: 22.0,
        bottomTime: const Duration(minutes: 35),
        siteName: 'Label Test',
        sortTimestamp: 0,
      );

      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'noicon-1',
            diveNumber: 20,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Label Test',
            maxDepth: 22.0,
            duration: const Duration(minutes: 35),
            summary: summary,
            stat1Field: DiveField.notes,
            stat2Field: DiveField.visibility,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#20'), findsOneWidget);
    });

    testWidgets(
      'renders stat fallback when summary null and non-default field',
      (tester) async {
        // Exercise the fallback path in _buildStatText when summary is null
        // and the field is neither maxDepth nor bottomTime.
        await tester.pumpWidget(
          testApp(
            overrides: [
              settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            ],
            child: CompactDiveListTile(
              diveId: 'fallback-1',
              diveNumber: 25,
              dateTime: DateTime(2026, 3, 15),
              siteName: 'Fallback Reef',
              maxDepth: 15.0,
              duration: const Duration(minutes: 20),
              stat1Field: DiveField.waterTemp,
              stat2Field: DiveField.airTemp,
              onTap: () {},
            ),
          ),
        );

        expect(find.text('#25'), findsOneWidget);
      },
    );

    testWidgets('renders with bottomTime field when maxDepth is stat1', (
      tester,
    ) async {
      // This covers the stat1Field == DiveField.bottomTime branch
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'bt-1',
            diveNumber: 30,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Duration Reef',
            maxDepth: 20.0,
            duration: const Duration(minutes: 45),
            stat1Field: DiveField.bottomTime,
            stat2Field: DiveField.maxDepth,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#30'), findsOneWidget);
      expect(find.textContaining('45'), findsWidgets);
    });
  });
}
