import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_equipment_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gear_geofence.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_gear_tree_view.dart';
import 'package:submersion/features/dive_log/presentation/widgets/geofence_suggestion_banner.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/set_bundle_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

/// The Equipment card of the dive page, edited in place (issue #4527,
/// plan 5).
void main() {
  final l = AppLocalizationsEn();
  final t0 = DateTime.utc(2026, 3, 9);
  const wing = EquipmentItem(
    id: 'wing',
    name: 'Wing',
    type: EquipmentType.wing,
  );
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Fins',
    type: EquipmentType.fins,
  );
  const mask = EquipmentItem(
    id: 'mask',
    name: 'Mask',
    type: EquipmentType.mask,
  );
  const reef = DiveSite(
    id: 'reef',
    name: 'Reef',
    location: GeoPoint(27.0, 34.0),
    altitude: 0,
  );
  final warm = EquipmentSet(
    id: 'warm',
    name: 'Warm water',
    equipmentIds: const ['wing'],
    items: const [wing],
    createdAt: t0,
    updatedAt: t0,
  );
  final dive = Dive(
    id: 'dive',
    dateTime: t0,
    gear: const [
      GearLink(item: fins),
      GearLink(item: mask, viaSetId: 'warm'),
    ],
  );

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<RecordEditController<Dive>> pump(
    WidgetTester tester,
    Dive d, {
    double width = 900,
    bool editor = true,
  }) async {
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(d);
    if (editor) controller.openCard('equipment');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          equipmentSetSelectionInputsProvider.overrideWith(
            (ref) async => EquipmentSetSelectionInputs(
              sets: [warm],
              geofences: [
                EquipmentSetGeofence(
                  id: 'g',
                  setId: 'warm',
                  latitude: 27,
                  longitude: 34,
                  radiusMeters: 5000,
                  createdAt: t0,
                  updatedAt: t0,
                ),
              ],
            ),
          ),
          setBundleProvider(
            'warm',
          ).overrideWith((ref) async => const SetBundle(setId: 'warm')),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordEditScope<Dive>(
                controller: controller,
                child: editor
                    ? DiveEquipmentCardEditor(session: controller.session!)
                    : DiveEquipmentSection(dive: controller.session!.working),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  /// Picks [reef] for the sitting, as the header's site row does.
  Future<void> pickReef(
    WidgetTester tester,
    RecordEditController<Dive> c,
  ) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    await tester.runAsync(() async {
      c.session!.set(diveSiteField, reef);
      reevaluateGearForSite(c.session!, read: container.read);
      await c.session!.settled();
    });
    await tester.pumpAndSettle();
  }

  testWidgets('opening and closing leaves the sitting clean', (tester) async {
    final c = await pump(tester, dive);
    c.closeCard('equipment');
    await tester.pumpAndSettle();
    expect(c.session!.isDirty, isFalse);
  });

  testWidgets('add from the picker, several at once', (tester) async {
    final c = await pump(tester, dive.copyWith(gear: const []));

    await tester.tap(find.text(l.diveLog_edit_add));
    await tester.pumpAndSettle();
    final sheet = tester.widget<EquipmentPickerSheet>(
      find.byType(EquipmentPickerSheet),
    );
    await tester.runAsync(() async {
      sheet.onEquipmentConfirmed!(const [fins, mask]);
      await c.session!.settled();
    });
    await tester.pumpAndSettle();

    expect(
      [for (final g in c.session!.working.gear) g.item.id],
      ['fins', 'mask'],
    );
    expect(c.session!.changedCardIds, {'equipment'});
  });

  testWidgets('a set removed asks keep or remove', (tester) async {
    final c = await pump(tester, dive);

    await tester.tap(find.byTooltip(l.diveLog_gear_removeSet).first);
    await tester.pumpAndSettle();
    expect(find.text(l.diveLog_gear_removeSetTitle), findsOneWidget);
    await tester.tap(find.text(l.diveLog_gear_removeSetKeepGear));
    await tester.pumpAndSettle();

    expect([for (final g in c.session!.working.gear) g.viaSetId], [null, null]);
  });

  testWidgets('a part removed through the gear tree keeps the rest', (
    tester,
  ) async {
    final c = await pump(tester, dive);

    tester
        .widget<DiveGearTreeView>(find.byType(DiveGearTreeView))
        .onRemovePart!('fins');
    await tester.pumpAndSettle();

    expect([for (final g in c.session!.working.gear) g.item.id], ['mask']);
    expect(c.session!.changedCardIds, {'equipment'});
  });

  testWidgets('Clear all empties the gear', (tester) async {
    final c = await pump(tester, dive);

    await tester.tap(find.text(l.diveLog_edit_clearAllEquipment));
    await tester.pumpAndSettle();

    expect(c.session!.working.gear, isEmpty);
    expect(find.text(l.diveLog_edit_noEquipmentSelected), findsOneWidget);
  });

  testWidgets('the suggestion applied fills the gear; dismissed, it goes', (
    tester,
  ) async {
    final c = await pump(tester, dive);
    await pickReef(tester, c);
    expect(find.byType(GeofenceSuggestionBanner), findsOneWidget);

    await tester.tap(find.text(l.diveLog_edit_geofenceSuggestion_apply));
    await tester.runAsync(() => c.session!.settled());
    await tester.pumpAndSettle();

    expect([
      for (final g in c.session!.working.gear) g.item.id,
    ], contains('wing'));
    expect(find.byType(GeofenceSuggestionBanner), findsNothing);
  });

  testWidgets('a dismissed suggestion goes', (tester) async {
    final c = await pump(tester, dive);
    await pickReef(tester, c);

    await tester.tap(find.text(l.common_action_dismiss));
    await tester.pumpAndSettle();

    expect(find.byType(GeofenceSuggestionBanner), findsNothing);
    expect(geofenceSuggestion(c.session!), isNull);
  });

  testWidgets('in the open card the suggestion waits while another card is '
      'open: it must not push that one down', (tester) async {
    final c = await pump(tester, dive);
    c.openCard('header');
    await pickReef(tester, c);
    expect(find.byType(GeofenceSuggestionBanner), findsNothing);

    c.closeCard('header');
    await tester.pumpAndSettle();
    expect(find.byType(GeofenceSuggestionBanner), findsOneWidget);
  });

  testWidgets('the closed card shows the suggestion only once the editors '
      'close', (tester) async {
    final c = await pump(tester, dive, editor: false);
    c.openCard('header');
    await pickReef(tester, c);
    expect(find.byType(GeofenceSuggestionBanner), findsNothing);

    c.closeCard('header');
    await tester.pumpAndSettle();
    expect(find.byType(GeofenceSuggestionBanner), findsOneWidget);
  });

  testWidgets('locked, the closed card shows no suggestion', (tester) async {
    final c = await pump(tester, dive, editor: false);
    await pickReef(tester, c);
    c.lock();
    await tester.pumpAndSettle();
    expect(find.byType(GeofenceSuggestionBanner), findsNothing);
  });

  testWidgets('the header actions fit at 360 px', (tester) async {
    await pump(tester, dive, width: 360);
    expect(tester.takeException(), isNull);
  });
}
