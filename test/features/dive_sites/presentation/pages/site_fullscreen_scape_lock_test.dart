import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_features_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_edit_save_provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_features_section.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import 'site_detail_page_unlock_harness.dart';

/// The site's fullscreen map obeys the site's lock (issue #4527, phase 2,
/// plan 3): opened from a locked page, or from anywhere but the Features
/// card's editor, it places nothing and offers no Edit; opened from that
/// editor, what it places goes to the sitting.
void main() {
  final l = AppLocalizationsEn();
  const site = DiveSite(
    id: 's1',
    diverId: 'me',
    name: 'Salt Pier',
    location: GeoPoint(12.151, -68.299),
  );
  const buoy = SiteFeature(
    id: 'f1',
    siteId: 's1',
    typeName: 'mooring',
    // Off the site's own pin, which would take the tap.
    latitude: 12.155,
    longitude: -68.295,
    name: 'Buoy',
  );

  setUp(() async {
    await setUpTestDatabase();
    // The sitting reads the features from the database, as stored.
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO dive_sites (id, name, latitude, longitude, created_at, "
      "updated_at) VALUES ('s1', 'Salt Pier', 12.151, -68.299, 0, 0)",
    );
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO site_features (id, site_id, type, name, latitude, "
      "longitude, notes, created_at, updated_at) VALUES "
      "('f1', 's1', 'mooring', 'Buoy', 12.155, -68.295, '', 0, 0)",
    );
  });

  tearDown(tearDownTestDatabase);

  // flutter_map never settles under flutter_test: bounded pumps only.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<FakeSiteSave> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 1400);
    addTearDown(tester.view.reset);
    final save = FakeSiteSave(site);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          validatedCurrentDiverIdProvider.overrideWith((_) async => 'me'),
          siteProvider(site.id).overrideWith((_) async => site),
          siteDiveCountProvider(site.id).overrideWith((_) async => 0),
          siteEditSaveServiceProvider.overrideWithValue(save),
          bathymetryGridProvider.overrideWith((ref, cell) async => null),
          siteFeaturesProvider(site.id).overrideWith((_) async => [buoy]),
          siteEditableProvider(site.id).overrideWith((_) async => true),
        ].cast<Override>(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteDetailPage(siteId: 's1', unlockEditing: true),
        ),
      ),
    );
    await settle(tester);
    return save;
  }

  Finder previewFullscreen() => find.descendant(
    of: find
        .ancestor(
          of: find.byType(FlutterMap).first,
          matching: find.byType(Card),
        )
        .first,
    matching: find.byIcon(Icons.fullscreen),
  );

  Future<void> tapFullscreenMarker(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('siteFeatureMarker-f1')).last);
    await settle(tester);
  }

  testWidgets('the locked page offers no feature edit on its card', (
    tester,
  ) async {
    await pump(tester);

    // The card shows the feature, but neither adds one nor edits it: on a
    // page that edits in place, only the Features editor does.
    expect(find.byKey(const ValueKey('siteFeatureRow-f1')), findsOneWidget);
    expect(find.byKey(const ValueKey('siteFeatureAddButton')), findsNothing);
    final editor = find.byWidgetPredicate(
      (w) => w is SiteFeaturesSection && w.onAddFeature == null,
    );
    expect(editor, findsOneWidget);
  });

  testWidgets('opened from a locked page it offers no Edit', (tester) async {
    await pump(tester);

    await tester.tap(previewFullscreen());
    await settle(tester);
    await tapFullscreenMarker(tester);

    expect(find.byKey(const ValueKey('siteFeatureInfoSheet')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('siteFeatureInfoEditButton')),
      findsNothing,
    );
  });

  testWidgets('opened from the Features editor a placed feature goes to the '
      'sitting', (tester) async {
    final save = await pump(tester);
    await tester.tap(find.byIcon(Icons.lock_outline));
    await settle(tester);
    final pencil = find.byTooltip(
      l.recordEdit_editCardTooltip(l.siteFeature_sectionTitle),
    );
    await tester.ensureVisible(pencil);
    await tester.tap(pencil);
    await settle(tester);
    final controller = RecordEditScope.maybeOf<DiveSite>(
      tester.element(find.byType(RecordCardFrame<DiveSite>).first),
    )!;

    await tester.ensureVisible(
      find.byKey(const ValueKey('siteFeatureAddButton')),
    );
    await tester.tap(find.byKey(const ValueKey('siteFeatureAddButton')));
    await settle(tester);
    expect(
      find.byKey(const ValueKey('siteFeaturePlaceBanner')),
      findsOneWidget,
    );
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap).last));
    await settle(tester);
    // The sheet lays itself out below this tall test view; its own test
    // taps the button.
    tester
        .widget<ButtonStyleButton>(
          find.byKey(const ValueKey('siteFeatureSaveButton')),
        )
        .onPressed!();
    await settle(tester);

    final features = siteFeaturesList.current(controller.session!)!;
    expect(features, hasLength(2));
    expect(controller.session!.changedCardIds, {'features'});
    expect(save.calls, isEmpty);
  });

  testWidgets('the sitting ending makes it read only', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.lock_outline));
    await settle(tester);
    final pencil = find.byTooltip(
      l.recordEdit_editCardTooltip(l.siteFeature_sectionTitle),
    );
    await tester.ensureVisible(pencil);
    await tester.tap(pencil);
    await settle(tester);
    final controller = RecordEditScope.maybeOf<DiveSite>(
      tester.element(find.byType(RecordCardFrame<DiveSite>).first),
    )!;
    await tester.ensureVisible(
      find.byKey(const ValueKey('siteFeatureAddButton')),
    );
    await tester.tap(find.byKey(const ValueKey('siteFeatureAddButton')));
    await settle(tester);

    controller.lock();
    await settle(tester);
    await tapFullscreenMarker(tester);

    expect(
      find.byKey(const ValueKey('siteFeatureInfoEditButton')),
      findsNothing,
    );
  });

  testWidgets('clearing the coordinates keeps the Features card in place '
      'while another editor is open', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.lock_outline));
    await settle(tester);
    final controller = RecordEditScope.maybeOf<DiveSite>(
      tester.element(find.byType(RecordCardFrame<DiveSite>).first),
    )!;
    controller.openCard('notes');
    await settle(tester);

    controller.session!.set(siteLocationField, null);
    await settle(tester);

    // No card comes or goes above an open editor.
    expect(find.byType(SiteFeaturesSection), findsOneWidget);
  });
}
