import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_align_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_correction_card.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/editing/nav_track_edit_cards.dart';
import 'package:submersion/features/nav_track/presentation/editing/nav_track_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../pages/nav_track_detail_page_unlock_harness.dart'
    show candidateDive, navRoute, newSite, oldSite;

/// The underwater track's card editors (issue #4527, plan 5): each sets
/// only its own card's values.
void main() {
  final l = AppLocalizationsEn();

  const scooter = EquipmentItem(
    id: 'eq1',
    name: 'Test Scooter',
    type: EquipmentType.dpv,
  );

  Future<EditSession<NavTrack>> pump(
    WidgetTester tester,
    Widget Function(EditSession<NavTrack> session) editor, {
    NavTrack? route,
  }) async {
    final overrides = await getBaseOverrides();
    final session = EditSession(route ?? navRoute());
    addTearDown(session.dispose);
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          divesProvider.overrideWith((ref) async => [candidateDive]),
          diveProvider(
            candidateDive.id,
          ).overrideWith((ref) async => candidateDive),
          siteProvider(oldSite.id).overrideWith((ref) async => oldSite),
          siteProvider(newSite.id).overrideWith((ref) async => newSite),
          sitesProvider.overrideWith((ref) async => [oldSite, newSite]),
          activeEquipmentProvider.overrideWith((ref) async => [scooter]),
          equipmentItemProvider(
            scooter.id,
          ).overrideWith((ref) async => scooter),
          bathymetryGridProvider.overrideWith((ref, cell) async => null),
        ],
        child: editor(session),
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  testWidgets('choosing a dive sets only the dive field', (tester) async {
    final session = await pump(
      tester,
      (session) => NavTrackDiveCardEditor(session: session),
    );

    await tester.tap(find.byKey(const ValueKey('nav-track-edit-choose-dive')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('#9'));
    await tester.pumpAndSettle();

    expect(session.valueOf(navTrackDiveField), 'dive-9');
    expect(session.changedCardIds, {'dive'});
  });

  testWidgets('unlink clears the dive and nothing else', (tester) async {
    final session = await pump(
      tester,
      (session) => NavTrackDiveCardEditor(session: session),
    );

    await tester.tap(find.byKey(const ValueKey('nav-track-edit-unlink')));
    await tester.pumpAndSettle();

    expect(session.valueOf(navTrackDiveField), isNull);
    expect(session.changedCardIds, {'dive'});
    expect(find.byKey(const ValueKey('nav-track-edit-unlink')), findsNothing);
  });

  testWidgets('a site pick sets the site and moves a following anchor', (
    tester,
  ) async {
    final session = await pump(
      tester,
      (session) => NavTrackSiteCardEditor(session: session),
    );

    await tester.tap(find.byKey(const ValueKey('nav-track-edit-change-site')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(newSite.name));
    await tester.pumpAndSettle();

    expect(session.valueOf(navTrackSiteField), newSite.id);
    expect(session.valueOf(navTrackAnchorField), newSite.location);
    expect(session.changedCardIds, {'site', 'correction'});
    expect(session.valueOf(navTrackDiveField), 'dive-1');
  });

  testWidgets('the name editor writes through as the diver types', (
    tester,
  ) async {
    final session = await pump(
      tester,
      (session) => NavTrackHeaderCardEditor(session: session),
    );

    await tester.enterText(find.byType(TextField), 'Evening');
    await tester.pump();

    expect(session.valueOf(navTrackNameField), 'Evening');
    expect(session.changedCardIds, {'header'});
  });

  testWidgets('choosing a device sets the item and its name together', (
    tester,
  ) async {
    final session = await pump(
      tester,
      (session) => NavTrackDeviceCardEditor(session: session),
    );
    expect(find.text(l.navTrack_detail_noEquipment), findsOneWidget);
    expect(find.text(l.navTrack_detail_chooseDevice), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('nav-track-edit-change-device')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-track-equipment-eq1')));
    await tester.pumpAndSettle();

    expect(session.valueOf(navTrackDeviceField), (
      equipmentId: 'eq1',
      deviceName: 'Test Scooter',
    ));
    expect(session.changedCardIds, {'device'});
    expect(find.text('Test Scooter'), findsOneWidget);
    expect(find.text(l.navTrack_detail_menuChangeDevice), findsOneWidget);
  });

  testWidgets('"no equipment" clears both device values', (tester) async {
    final session = await pump(
      tester,
      (session) => NavTrackDeviceCardEditor(session: session),
      route: navRoute().copyWith(equipmentId: 'eq1', deviceName: 'Box'),
    );

    await tester.tap(
      find.byKey(const ValueKey('nav-track-edit-change-device')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-track-equipment-none')));
    await tester.pumpAndSettle();

    expect(session.valueOf(navTrackDeviceField), (
      equipmentId: null,
      deviceName: null,
    ));
  });

  testWidgets('dismissing the device picker changes nothing', (tester) async {
    final session = await pump(
      tester,
      (session) => NavTrackDeviceCardEditor(session: session),
    );

    await tester.tap(
      find.byKey(const ValueKey('nav-track-edit-change-device')),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(session.changedCardIds, isEmpty);
  });

  testWidgets('a site with no site yet offers Choose site', (tester) async {
    final session = await pump(
      tester,
      (session) => NavTrackSiteCardEditor(session: session),
      route: NavTrack(
        id: 'r1',
        source: NavTrackSource.seacraftEnc,
        startTime: 0,
        endTime: 1,
        pointCount: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    expect(find.text(l.navTrack_detail_noSite), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-track-edit-change-site')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(newSite.name));
    await tester.pumpAndSettle();

    // No anchor to follow the old pin: the new site's pin becomes it.
    expect(session.valueOf(navTrackSiteField), newSite.id);
    expect(session.valueOf(navTrackAnchorField), newSite.location);
  });

  testWidgets('the Correction editor opens the align page in the sitting', (
    tester,
  ) async {
    final controller = RecordEditController<NavTrack>(onSave: (_) async {});
    addTearDown(controller.dispose);
    controller.unlock(navRoute());
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          navTrackByIdProvider('r1').overrideWith((ref) async => navRoute()),
          bathymetryGridProvider.overrideWith((ref, cell) async => null),
        ],
        child: RecordEditScope<NavTrack>(
          controller: controller,
          child: NavTrackCorrectionCardEditor(session: controller.session!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavTrackCorrectionCard), findsOneWidget);

    await tester.tap(find.byType(NavTrackCorrectionCard));
    await tester.pumpAndSettle();

    final page = tester.widget<NavTrackAlignPage>(
      find.byType(NavTrackAlignPage),
    );
    expect(page.joinedSitting, same(controller));
    expect(find.byKey(const ValueKey('nav-track-align-done')), findsOneWidget);
  });
}
