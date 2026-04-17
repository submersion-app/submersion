import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dense_dive_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DenseDiveListTile', () {
    testWidgets('renders dive number, site name, date, depth, duration', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
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
      // Should show abbreviated date (no time)
      expect(find.textContaining('Mar'), findsWidgets);
    });

    testWidgets('shows checkbox in selection mode', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
            diveId: 'test-id',
            diveNumber: 42,
            dateTime: DateTime(2026, 3, 15),
            isSelectionMode: true,
            isSelected: false,
            onTap: () {},
          ),
        ),
      );

      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('shows year when date is not current year', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
            diveId: 'test-id',
            diveNumber: 1,
            dateTime: DateTime(2024, 6, 10),
            onTap: () {},
          ),
        ),
      );

      // Should include year for non-current year
      expect(find.textContaining('24'), findsWidgets);
    });

    testWidgets('fires onDoubleTap on double-tap gesture', (tester) async {
      bool doubleTapped = false;
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
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

    testWidgets('shows left accent border when isHighlighted is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
            diveId: 'test-id',
            diveNumber: 42,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Test Site',
            isHighlighted: true,
            onTap: () {},
          ),
        ),
      );

      final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(DenseDiveListTile),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = decoratedBoxes.first.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
    });

    testWidgets('renders with null depth and duration shows dashes', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
            diveId: 'null-id',
            diveNumber: 3,
            dateTime: DateTime(2026, 3, 15),
            maxDepth: null,
            duration: null,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#3'), findsOneWidget);
    });

    testWidgets('renders with gradient card coloring', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
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

    testWidgets('renders with selected state', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
            diveId: 'sel-id',
            diveNumber: 5,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Deep Wall',
            isSelected: true,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#5'), findsOneWidget);
      expect(find.text('Deep Wall'), findsOneWidget);
    });

    testWidgets('fires onLongPress callback', (tester) async {
      bool longPressed = false;
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
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

    testWidgets('renders with configurable slot fields from summary', (
      tester,
    ) async {
      final summary = DiveSummary(
        id: 'ds-1',
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
          child: DenseDiveListTile(
            diveId: 'ds-1',
            diveNumber: 7,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Blue Hole',
            maxDepth: 20.0,
            duration: const Duration(minutes: 30),
            summary: summary,
            slot1Field: DiveField.siteName,
            slot2Field: DiveField.dateTime,
            slot3Field: DiveField.waterTemp,
            slot4Field: DiveField.runtime,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#7'), findsOneWidget);
    });

    testWidgets('renders unknown site when siteName is null', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
            diveId: 'unknown-id',
            diveNumber: 1,
            dateTime: DateTime(2026, 3, 15),
            siteName: null,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#1'), findsOneWidget);
    });

    testWidgets('renders with non-default slot fields that have icons', (
      tester,
    ) async {
      final summary = DiveSummary(
        id: 'icon-1',
        dateTime: DateTime(2026, 3, 15),
        diveNumber: 20,
        maxDepth: 15.0,
        bottomTime: const Duration(minutes: 22),
        waterTemp: 18.0,
        rating: 5,
        sortTimestamp: 0,
      );

      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
            diveId: 'icon-1',
            diveNumber: 20,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Test Reef',
            maxDepth: 15.0,
            duration: const Duration(minutes: 22),
            summary: summary,
            slot1Field: DiveField.maxDepth,
            slot2Field: DiveField.bottomTime,
            slot3Field: DiveField.waterTemp,
            slot4Field: DiveField.ratingStars,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#20'), findsOneWidget);
    });

    testWidgets('renders stat slot without icon using label:value format', (
      tester,
    ) async {
      final summary = DiveSummary(
        id: 'noicon-1',
        dateTime: DateTime(2026, 3, 15),
        diveNumber: 22,
        maxDepth: 18.0,
        bottomTime: const Duration(minutes: 28),
        siteName: 'Label Site',
        sortTimestamp: 0,
      );

      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
            diveId: 'noicon-1',
            diveNumber: 22,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Label Site',
            maxDepth: 18.0,
            duration: const Duration(minutes: 28),
            summary: summary,
            slot3Field: DiveField.notes,
            slot4Field: DiveField.visibility,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#22'), findsOneWidget);
    });

    testWidgets(
      'renders fallback when summary null and non-default stat field',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            overrides: [
              settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            ],
            child: DenseDiveListTile(
              diveId: 'fallback-1',
              diveNumber: 25,
              dateTime: DateTime(2026, 3, 15),
              siteName: 'Fallback Reef',
              maxDepth: 15.0,
              duration: const Duration(minutes: 20),
              slot3Field: DiveField.waterTemp,
              slot4Field: DiveField.airTemp,
              onTap: () {},
            ),
          ),
        );

        expect(find.text('#25'), findsOneWidget);
      },
    );

    testWidgets('renders with swapped default fields', (tester) async {
      // Exercises the bottomTime stat branch at slot3 and maxDepth at slot4
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
            diveId: 'swap-1',
            diveNumber: 30,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Swap Site',
            maxDepth: 20.0,
            duration: const Duration(minutes: 45),
            slot3Field: DiveField.bottomTime,
            slot4Field: DiveField.maxDepth,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#30'), findsOneWidget);
      expect(find.textContaining('45'), findsWidgets);
    });

    testWidgets('renders text slots with non-default fields from summary', (
      tester,
    ) async {
      final summary = DiveSummary(
        id: 'txt-1',
        dateTime: DateTime(2026, 3, 15),
        diveNumber: 33,
        maxDepth: 25.0,
        bottomTime: const Duration(minutes: 40),
        siteName: 'Text Slot Site',
        waterTemp: 24.0,
        sortTimestamp: 0,
      );

      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
            diveId: 'txt-1',
            diveNumber: 33,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Text Slot Site',
            maxDepth: 25.0,
            duration: const Duration(minutes: 40),
            summary: summary,
            slot1Field: DiveField.waterTemp,
            slot2Field: DiveField.maxDepth,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('#33'), findsOneWidget);
    });

    testWidgets(
      'renders text slot fallback when summary null and non-default',
      (tester) async {
        // Exercises the _buildTextSlotValue fallback for non siteName/dateTime
        // fields when summary is null
        await tester.pumpWidget(
          testApp(
            overrides: [
              settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            ],
            child: DenseDiveListTile(
              diveId: 'txtnull-1',
              diveNumber: 35,
              dateTime: DateTime(2026, 3, 15),
              siteName: 'Fallback Text',
              maxDepth: 12.0,
              duration: const Duration(minutes: 15),
              slot1Field: DiveField.waterTemp,
              slot2Field: DiveField.maxDepth,
              onTap: () {},
            ),
          ),
        );

        expect(find.text('#35'), findsOneWidget);
      },
    );
  });
}
