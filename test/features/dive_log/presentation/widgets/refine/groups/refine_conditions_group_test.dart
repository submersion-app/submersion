import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_conditions_group.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../../../helpers/mock_providers.dart';
import 'group_test_host.dart';

void main() {
  Future<GroupHarness> pump(
    WidgetTester tester, {
    DiveFilterState initial = const DiveFilterState(),
    AppSettings settings = const AppSettings(),
  }) async => pumpGroup(
    tester,
    (d, on) => RefineConditionsGroup(draft: d, onChanged: on),
    initial: initial,
    baseOverrides: await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    ),
  );

  const imperial = AppSettings(
    depthUnit: DepthUnit.feet,
    temperatureUnit: TemperatureUnit.fahrenheit,
  );

  testWidgets('depth in feet is stored in metres', (tester) async {
    final h = await pump(tester, settings: imperial);
    await tester.enterText(
      find.byKey(const ValueKey('refine-depth-min')),
      '100',
    );
    await tester.pump();
    expect(h.draft.minDepth, closeTo(30.48, 0.001));
  });

  testWidgets('a negative Fahrenheit bound is stored in Celsius', (
    tester,
  ) async {
    final h = await pump(tester, settings: imperial);
    await tester.enterText(
      find.byKey(const ValueKey('filter-water-temp-min')),
      '-4',
    );
    await tester.pump();
    expect(h.draft.minWaterTemp, closeTo(-20, 0.001));
  });

  testWidgets('a typo keeps the bound; blank clears it', (tester) async {
    final h = await pump(
      tester,
      initial: const DiveFilterState(minDepth: 30, maxVisibility: 10),
    );
    await tester.enterText(
      find.byKey(const ValueKey('refine-depth-min')),
      '30..',
    );
    await tester.pump();
    expect(h.draft.minDepth, 30);
    await tester.enterText(
      find.byKey(const ValueKey('filter-visibility-max')),
      '',
    );
    await tester.pump();
    expect(h.draft.maxVisibility, isNull);
  });

  testWidgets('bottom time, deco and water types write', (tester) async {
    final h = await pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('refine-duration-min')),
      '45',
    );
    await tester.pump();
    expect(h.draft.minBottomTimeMinutes, 45);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Yes'));
    await tester.pump();
    expect(h.draft.decoOnly, isTrue);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Any'));
    await tester.pump();
    expect(h.draft.decoOnly, isNull);
  });

  testWidgets('water type chips toggle', (tester) async {
    final h = await pump(tester);
    final chip = find.byType(FilterChip).first;
    await tester.tap(chip);
    await tester.pump();
    expect(h.draft.waterTypes, hasLength(1));
    await tester.tap(chip);
    await tester.pump();
    expect(h.draft.waterTypes, isEmpty);
  });

  // Review Focus 1: seeding the fields in display units never writes back,
  // so untouched bounds keep their exact metric values.
  testWidgets('untouched bounds do not drift through display units', (
    tester,
  ) async {
    const seeded = DiveFilterState(
      minDepth: 30.48,
      maxDepth: 40.1,
      minWaterTemp: 21.11,
      minVisibility: 12.3,
    );
    final h = await pump(tester, initial: seeded, settings: imperial);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Yes'));
    await tester.pump();
    expect(h.draft.minDepth, 30.48);
    expect(h.draft.maxDepth, 40.1);
    expect(h.draft.minWaterTemp, 21.11);
    expect(h.draft.minVisibility, 12.3);
  });

  test('declares its fields', () {
    expect(RefineConditionsGroup.fields, {
      'minDepth',
      'maxDepth',
      'minBottomTimeMinutes',
      'maxBottomTimeMinutes',
      'decoOnly',
      'minWaterTemp',
      'maxWaterTemp',
      'minVisibility',
      'maxVisibility',
      'waterTypes',
    });
    expect(
      RefineConditionsGroup.activeCount(
        const DiveFilterState(minDepth: 1, maxDepth: 2, decoOnly: false),
      ),
      2,
    );
  });

  // Code review: a unit change while the panel is open re-reads the bounds
  // in the new unit (the Advanced Search page did; seeding never writes).
  testWidgets('a unit change re-seeds the bound fields', (tester) async {
    final h = await pump(tester, initial: const DiveFilterState(minDepth: 30));
    String depthText() => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(const ValueKey('refine-depth-min')),
            matching: find.byType(TextField),
          ),
        )
        .controller!
        .text;
    expect(depthText(), '30');
    (h.container.read(settingsProvider.notifier) as MockSettingsNotifier)
        .state = const AppSettings(
      depthUnit: DepthUnit.feet,
    );
    await tester.pumpAndSettle();
    expect(depthText(), '98');
    expect(h.draft.minDepth, 30, reason: 're-seeding never writes');
  });
}
