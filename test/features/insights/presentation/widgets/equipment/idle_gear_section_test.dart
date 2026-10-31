import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/reports/idle_gear.dart';
import 'package:submersion/features/insights/presentation/providers/equipment_report_insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/equipment/idle_gear_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

EquipmentItem _item(String name) =>
    EquipmentItem(id: name, name: name, type: EquipmentType.mask);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Future<List<IdleRow>> Function() load,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [idleGearProvider.overrideWith((ref) => load())],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: IdleGearSection())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(IdleGearSection)),
  );
}

void main() {
  testWidgets('a row reads 2 yrs 4 mo, and Never dived', (tester) async {
    await _pump(
      tester,
      () async => [
        IdleRow(
          item: _item('Backup mask'),
          lastDive: DateTime.utc(2024, 6, 1),
          since: (years: 2, months: 4),
        ),
        IdleRow(item: _item('Smoke marker')),
      ],
    );

    expect(find.text('Idle gear'), findsOneWidget);
    expect(find.text('2 yrs 4 mo'), findsOneWidget);
    expect(find.text('Never dived'), findsOneWidget);
  });

  testWidgets('leaves out a zero part of the time', (tester) async {
    await _pump(
      tester,
      () async => [
        IdleRow(
          item: _item('a'),
          lastDive: DateTime.utc(2024, 6, 1),
          since: (years: 1, months: 0),
        ),
        IdleRow(
          item: _item('b'),
          lastDive: DateTime.utc(2024, 6, 1),
          since: (years: 0, months: 7),
        ),
      ],
    );

    expect(find.text('1 yr'), findsOneWidget);
    expect(find.text('7 mo'), findsOneWidget);
  });

  testWidgets('choosing a period stores it', (tester) async {
    final container = await _pump(tester, () async => const []);
    expect(container.read(idlePeriodProvider), IdlePeriod.oneYear);

    await tester.tap(find.byKey(const ValueKey('idle-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Over 2 years').last);
    await tester.pumpAndSettle();

    expect(container.read(idlePeriodProvider), IdlePeriod.twoYears);
  });

  testWidgets('nothing idle shows the empty text', (tester) async {
    await _pump(tester, () async => const []);
    expect(find.text('All your gear has been dived recently'), findsOneWidget);
  });

  testWidgets('a failed load shows the error, not the empty text', (
    tester,
  ) async {
    await _pump(tester, () async => throw StateError('no db'));
    expect(find.text('Could not load idle gear'), findsOneWidget);
    expect(find.text('All your gear has been dived recently'), findsNothing);
  });

  testWidgets('show all expands past ten', (tester) async {
    await _pump(
      tester,
      () async => [
        for (var i = 0; i < 12; i++) IdleRow(item: _item('item $i')),
      ],
    );
    expect(find.text('item 11'), findsNothing);
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.text('item 11'), findsOneWidget);
  });
}
