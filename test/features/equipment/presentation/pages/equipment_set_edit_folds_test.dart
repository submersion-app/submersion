import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The set editor folds its type groups (issue #3364): groups holding the
/// set's members start open, the rest closed, and a fold keeps the ticks.
void main() {
  const zeagle = EquipmentItem(
    id: 'bcd-1',
    name: 'Zeagle',
    type: EquipmentType.bcd,
  );
  const faber = EquipmentItem(
    id: 'tank-1',
    name: 'Faber',
    type: EquipmentType.tank,
  );
  const fins = EquipmentItem(
    id: 'fins-1',
    name: 'Jet fins',
    type: EquipmentType.fins,
  );

  final set = EquipmentSet(
    id: 'set-1',
    diverId: 'diver-1',
    name: 'Cold Water',
    equipmentIds: const ['bcd-1', 'tank-1'],
    items: const [zeagle, faber],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentSetProvider('set-1').overrideWith((ref) async => set),
          activeEquipmentProvider.overrideWith(
            (ref) async => const [zeagle, faber, fins],
          ),
          allEquipmentProvider.overrideWith(
            (ref) async => const [zeagle, faber, fins],
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EquipmentSetEditPage(setId: 'set-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder typeHeader(EquipmentType type) =>
      find.byKey(ValueKey('equipment-type-fold-type:${type.name}'));

  // The diver figure labels members too, so look only inside the rows.
  Finder row(String name) => find.descendant(
    of: find.byType(CheckboxListTile),
    matching: find.text(name),
  );

  testWidgets('groups holding members start open, others closed', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(row('Zeagle'), findsOneWidget);
    expect(row('Faber'), findsOneWidget);
    expect(typeHeader(EquipmentType.fins), findsOneWidget);
    expect(row('Jet fins'), findsNothing);
  });

  testWidgets('folding keeps the ticks and says so', (tester) async {
    await pumpPage(tester);
    await tester.tap(typeHeader(EquipmentType.bcd));
    await tester.pumpAndSettle();
    expect(row('Zeagle'), findsNothing);
    expect(find.text('1 of 1 selected'), findsOneWidget);

    await tester.tap(typeHeader(EquipmentType.bcd));
    await tester.pumpAndSettle();
    final tile = find.ancestor(
      of: row('Zeagle'),
      matching: find.byType(CheckboxListTile),
    );
    expect(tester.widget<CheckboxListTile>(tile).value, isTrue);
  });
}
