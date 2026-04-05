import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dense_dive_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

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
  });
}
