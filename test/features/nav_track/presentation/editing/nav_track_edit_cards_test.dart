import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
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
  Future<EditSession<NavTrack>> pump(
    WidgetTester tester,
    Widget Function(EditSession<NavTrack> session) editor,
  ) async {
    final overrides = await getBaseOverrides();
    final session = EditSession(navRoute());
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
}
