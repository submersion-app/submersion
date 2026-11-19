import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_card_editors.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';

/// The equipment set page's card editors (issue #4527, phase 3) each hold
/// only their own card's values.
void main() {
  final t0 = DateTime(2026);
  final cold = EquipmentSet(
    id: 's1',
    diverId: 'd1',
    name: 'Cold water',
    equipmentIds: const ['e1'],
    showFigure: false,
    createdAt: t0,
    updatedAt: t0,
  );
  // Has includes of its own, so nesting one level deep, s1 cannot
  // include it.
  final outer = EquipmentSet(
    id: 'outer',
    diverId: 'd1',
    name: 'Expedition',
    includedSetIds: const ['plain'],
    createdAt: t0,
    updatedAt: t0,
  );
  final plain = EquipmentSet(
    id: 'plain',
    diverId: 'd1',
    name: 'Pool kit',
    createdAt: t0,
    updatedAt: t0,
  );

  Future<EditSession<EquipmentSet>> pumpEditor(
    WidgetTester tester,
    Widget Function(EditSession<EquipmentSet> session) editor, {
    EquipmentSet? start,
    List<EquipmentItem> gear = const [],
    List<EquipmentSet>? sets,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final session = EditSession(start ?? cold);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          allEquipmentProvider.overrideWith((ref) async => gear),
          equipmentSetsProvider.overrideWith(
            (ref) async => sets ?? [cold, outer, plain],
          ),
          weightPresetsProvider.overrideWith((ref) async => const []),
          cylinderConfigsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: editor(session))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  testWidgets("each editor sets only its card's fields", (tester) async {
    final header = await pumpEditor(
      tester,
      (s) => EquipmentSetHeaderEditor(session: s),
    );
    await tester.enterText(find.byKey(const ValueKey('set-edit-name')), 'Kelp');
    await tester.pumpAndSettle();
    expect(header.changedCardIds, {'header'});

    final figure = await pumpEditor(
      tester,
      (s) => EquipmentSetFigureEditor(session: s),
    );
    await tester.tap(find.byKey(const ValueKey('set-edit-show-figure')));
    await tester.pumpAndSettle();
    expect(figure.changedCardIds, {'figure'});
  });

  testWidgets('the header count reads the gear when the set was read without '
      'its items', (tester) async {
    // As after a Save: the saved set comes back without its items, and a
    // sitting can start from it before the page reads the set again.
    EquipmentItem item(String id) =>
        EquipmentItem(id: id, name: id, type: EquipmentType.bcd);
    final withPlain = cold.copyWith(includedSetIds: ['plainGear']);
    final plainGear = EquipmentSet(
      id: 'plainGear',
      diverId: 'd1',
      name: 'Fins',
      equipmentIds: const ['e2', 'e3'],
      createdAt: t0,
      updatedAt: t0,
    );
    await pumpEditor(
      tester,
      (s) => EquipmentSetHeaderEditor(session: s),
      start: withPlain,
      gear: [item('e1'), item('e2'), item('e3')],
      sets: [withPlain, plainGear],
    );

    expect(find.text('3 items'), findsOneWidget);
  });

  testWidgets('the Default and auto-apply switches are held', (tester) async {
    final session = await pumpEditor(
      tester,
      (s) => EquipmentSetHeaderEditor(session: s),
    );

    await tester.tap(find.byKey(const ValueKey('set-edit-default')));
    await tester.tap(find.byKey(const ValueKey('set-edit-auto-apply')));
    await tester.pumpAndSettle();

    expect(session.working.isDefault, isTrue);
    expect(session.working.autoApplyOnComputerImport, isTrue);
    expect(session.changedCardIds, {'header'});
  });

  testWidgets('the Bundle editor offers no set that includes sets', (
    tester,
  ) async {
    final session = await pumpEditor(
      tester,
      (s) => EquipmentSetBundleEditor(session: s),
    );

    await tester.tap(find.byKey(const Key('set-bundle-add-includes')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('set-bundle-option-plain')), findsOneWidget);
    expect(find.byKey(const Key('set-bundle-option-outer')), findsNothing);
    await tester.tap(find.byKey(const Key('set-bundle-option-plain')));
    await tester.pumpAndSettle();
    expect(session.working.includedSetIds, ['plain']);
    expect(session.changedCardIds, {'bundle'});
  });
}
