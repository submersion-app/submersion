import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_arrange_sheet.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeSettingsRepository extends AppSettingsRepository {
  _FakeSettingsRepository({this.stored, this.failWrite = false}) {
    // Self-registering so no construction site can forget it, and a new
    // one cannot reintroduce the leak.
    addTearDown(settingsTicks.close);
  }

  EquipmentArrangement? stored;
  bool failWrite;
  final List<EquipmentArrangement> written = [];
  final StreamController<void> settingsTicks = StreamController<void>();

  @override
  Future<EquipmentArrangement?> getEquipmentArrangement() async => stored;

  @override
  Future<void> setEquipmentArrangement(EquipmentArrangement arrangement) async {
    if (failWrite) throw StateError('write failed');
    written.add(arrangement);
    stored = arrangement;
  }

  @override
  Stream<void> watchSettingsChanges() => settingsTicks.stream;
}

void main() {
  Future<void> pumpSheet(
    WidgetTester tester,
    _FakeSettingsRepository fake,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showEquipmentArrangeSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('changing the type order writes the preference', (tester) async {
    final fake = _FakeSettingsRepository();
    await pumpSheet(tester, fake);

    await tester.tap(find.text('Head to toe'));
    await tester.pumpAndSettle();

    expect(fake.written.single.typeOrder, EquipmentTypeOrder.headToToe);
  });

  testWidgets('changing the item sort writes the preference', (tester) async {
    final fake = _FakeSettingsRepository();
    await pumpSheet(tester, fake);

    // The sheet now carries a direction toggle on the type axis too, so the
    // item-sort options sit below the fold on a short viewport.
    await tester.ensureVisible(find.text('Purchase date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Purchase date'));
    await tester.pumpAndSettle();

    expect(fake.written.single.itemSortField.name, 'purchaseDate');
  });

  testWidgets('the item order label reads "Sort by" when not grouping', (
    tester,
  ) async {
    final fake = _FakeSettingsRepository(
      stored: EquipmentArrangement.defaults.copyWith(groupByType: false),
    );
    await pumpSheet(tester, fake);

    expect(find.text('Sort by'), findsOneWidget);
    expect(find.text('Then by'), findsNothing);
  });

  testWidgets('grouping is disabled when nothing orders the types', (
    tester,
  ) async {
    // Grouping without a type ordering would draw headers in an arbitrary
    // sequence, which is the complaint this feature answers, so the arranger
    // forces headers off. The switch must not offer a control that does
    // nothing.
    final fake = _FakeSettingsRepository(
      stored: EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.none,
      ),
    );
    await pumpSheet(tester, fake);

    final tile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile).first,
    );
    expect(tile.onChanged, isNull);
  });

  testWidgets('reset restores the defaults', (tester) async {
    final fake = _FakeSettingsRepository(
      stored: EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.dressingOrder,
        groupByType: false,
      ),
    );
    await pumpSheet(tester, fake);

    // The sheet carries three axes, so on a short viewport the reset button
    // sits below the fold and the sheet scrolls to it.
    await tester.ensureVisible(find.text('Reset to defaults'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset to defaults'));
    await tester.pumpAndSettle();

    expect(fake.written.last, EquipmentArrangement.defaults);
  });

  testWidgets('a failed save shows a message and leaves state unchanged', (
    tester,
  ) async {
    final fake = _FakeSettingsRepository(failWrite: true);
    await pumpSheet(tester, fake);

    await tester.tap(find.text('Head to toe'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save the arrangement'), findsOneWidget);
    expect(fake.written, isEmpty);
  });

  testWidgets('the sheet header survives a narrow phone in Portuguese', (
    tester,
  ) async {
    // The longest translation of the title is 23 characters, beside a close
    // button, so an inflexible Text overflows a small phone.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fake = _FakeSettingsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showEquipmentArrangeSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
