import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_suggestion_card.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_suggestion_providers.dart';

import '../../../media/presentation/support/media_widget_harness.dart';
import '../support/fake_matching_service.dart';

/// Holds the apply open so the test can dispose the card mid-write.
class _BlockingMatchingService extends FakeMatchingService {
  final gate = Completer<void>();

  @override
  Future<ApplyResult> applyConfirmed(List<ConfirmedMatch> confirmed) async {
    await gate.future;
    return super.applyConfirmed(confirmed);
  }
}

class _StubDiveRepository implements DiveRepository {
  _StubDiveRepository({this.linkedSite});

  /// The site the dive is linked to when the card re-reads it after a write.
  final DiveSite? linkedSite;
  final dismissed = <String>[];

  @override
  Future<void> setSiteSuggestionDismissed(String diveId, bool value) async {
    if (value) dismissed.add(diveId);
  }

  @override
  Future<Dive?> getDiveById(String id) async => Dive(
    id: id,
    diveNumber: 1,
    dateTime: DateTime(2026, 1, 1),
    maxDepth: 18,
    site: linkedSite,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeMatchingService service;
  late _StubDiveRepository dives;
  var refreshed = 0;

  setUp(() {
    service = FakeMatchingService();
    dives = _StubDiveRepository();
    refreshed = 0;
  });

  Future<Widget> host(
    SiteSuggestion? suggestion, {
    DiveSite? currentSite,
    void Function(DiveSite)? onSiteChanged,
  }) => mediaTestApp(
    overrides: [
      siteSuggestionForDiveProvider(
        'd1',
      ).overrideWith((ref) async => suggestion),
      diveRepositoryProvider.overrideWithValue(dives),
    ],
    home: Scaffold(
      body: SiteSuggestionCard(
        diveId: 'd1',
        currentSite: currentSite,
        onSiteChanged: onSiteChanged,
        refreshLists: () async => refreshed++,
      ),
    ),
  );

  testWidgets('renders nothing when there is no suggestion', (tester) async {
    await tester.pumpWidget(await host(null));
    await tester.pumpAndSettle();
    expect(find.byType(SiteSuggestionCard), findsOneWidget);
    expect(find.textContaining('Location'), findsNothing);
  });

  testWidgets(
    'assign reports the site the dive was actually linked to, not the candidate',
    (tester) async {
      // A bundled candidate's id is its externalId; applyConfirmed
      // materialises a user site with a different database id (or the
      // coincidence guard links an existing one). The card must report the
      // dive's real site, or the edit form would save a site id that does
      // not exist.
      const linked = DiveSite(
        id: 'materialised-uuid',
        name: 'Blue Hole',
        location: GeoPoint(0, 0),
        maxDepth: 40,
      );
      dives = _StubDiveRepository(linkedSite: linked);
      final s = suggestionFor(
        service,
        recommended: 'osm_1',
        candidates: const [
          MatchCandidateView(
            id: 'osm_1',
            name: 'Blue Hole',
            isExisting: false,
            distanceMeters: 40,
            location: GeoPoint(0, 0),
          ),
        ],
      );
      DiveSite? reported;
      await tester.pumpWidget(
        await host(s, onSiteChanged: (site) => reported = site),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Assign Blue Hole'));
      await tester.pumpAndSettle();

      expect(service.applied.single.candidateId, 'osm_1');
      expect(
        reported?.id,
        'materialised-uuid',
        reason: 'the bundled externalId must never reach the form',
      );
      expect(reported?.maxDepth, 40, reason: 'and it must be fully hydrated');
      expect(refreshed, 1);
      expect(find.text('Assigned Blue Hole'), findsOneWidget);
    },
  );

  testWidgets('assign leaves the form alone when the dive has no site', (
    tester,
  ) async {
    dives = _StubDiveRepository();
    final s = suggestionFor(
      service,
      recommended: 's1',
      candidates: const [
        MatchCandidateView(
          id: 's1',
          name: 'Blue Hole',
          isExisting: true,
          distanceMeters: 40,
          location: GeoPoint(0, 0),
        ),
      ],
    );
    var reportedCount = 0;
    await tester.pumpWidget(
      await host(s, onSiteChanged: (_) => reportedCount++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Assign Blue Hole'));
    await tester.pumpAndSettle();

    expect(reportedCount, 0);
    expect(find.text('Assigned Blue Hole'), findsOneWidget);
  });

  testWidgets('hides when the edit form already holds a located site', (
    tester,
  ) async {
    // The dive is still siteless in the database, so the provider yields a
    // suggestion, but the diver has already picked a site with coordinates
    // and not saved it yet. Offering to place one would be noise.
    await tester.pumpWidget(
      await host(
        suggestionFor(service, status: ProposalStatus.none),
        currentSite: const DiveSite(
          id: 's1',
          name: 'Blue Hole',
          location: GeoPoint(0, 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Location'), findsNothing);
  });

  testWidgets('hides when the form holds a site the dive was not saved with', (
    tester,
  ) async {
    // addLocation writes to the dive's persisted site, so labelling the
    // button with the unsaved one would point at the wrong site entirely.
    await tester.pumpWidget(
      await host(
        suggestionFor(
          service,
          site: const DiveSite(id: 'persisted', name: 'Persisted'),
        ),
        currentSite: const DiveSite(id: 'unsaved', name: 'Elsewhere'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Location'), findsNothing);
  });

  testWidgets('hides when the host reports no site but the dive has one', (
    tester,
  ) async {
    // currentSite is the site the HOST shows, not an optional override: a
    // null means "this page is showing no site". It never falls back to the
    // dive's own site, or a page that forgot to pass one would offer to
    // place coordinates on a site it is not displaying.
    await tester.pumpWidget(
      await host(
        suggestionFor(
          service,
          site: const DiveSite(id: 'persisted', name: 'Persisted'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Location'), findsNothing);
  });

  testWidgets('add location reports the site as the repository has it', (
    tester,
  ) async {
    // The post-commit altitude pass can fill a field the local copy cannot
    // know about, so this path reads back like the assign path does.
    const persisted = DiveSite(id: 'bare', name: 'Typed Twice');
    dives = _StubDiveRepository(
      linkedSite: const DiveSite(
        id: 'bare',
        name: 'Typed Twice',
        location: GeoPoint(20.5, -87.25),
        altitude: 12,
      ),
    );
    DiveSite? reported;
    await tester.pumpWidget(
      await host(
        suggestionFor(service, site: persisted),
        currentSite: persisted,
        onSiteChanged: (site) => reported = site,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Add location to Typed Twice'));
    await tester.pumpAndSettle();

    expect(reported?.location, const GeoPoint(20.5, -87.25));
    expect(
      reported?.altitude,
      12,
      reason: 'the altitude pass ran; a local copyWith would have missed it',
    );
  });

  testWidgets('dismiss writes the flag', (tester) async {
    await tester.pumpWidget(
      await host(suggestionFor(service, status: ProposalStatus.none)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(dives.dismissed, ['d1']);
  });

  testWidgets('create opens the quick dialog and links the new site', (
    tester,
  ) async {
    DiveSite? reported;
    await tester.pumpWidget(
      await host(
        suggestionFor(service, status: ProposalStatus.none),
        onSiteChanged: (site) => reported = site,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Site'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Wall');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Site').last);
    await tester.pumpAndSettle();
    expect(service.created.single.name, 'Wall');
    expect(reported?.id, 'created');
    expect(find.textContaining('Created site: Wall'), findsOneWidget);
  });

  testWidgets('a write that finishes after disposal does not throw', (
    tester,
  ) async {
    // The diver taps Assign and navigates away before the write lands. The
    // write still commits, but ref and the host's setState are gone by then.
    final blocking = _BlockingMatchingService();
    dives = _StubDiveRepository(
      linkedSite: const DiveSite(id: 's1', name: 'Blue Hole'),
    );
    var reportedCount = 0;
    await tester.pumpWidget(
      await host(
        suggestionFor(
          blocking,
          recommended: 's1',
          candidates: const [
            MatchCandidateView(
              id: 's1',
              name: 'Blue Hole',
              isExisting: true,
              distanceMeters: 40,
              location: GeoPoint(0, 0),
            ),
          ],
        ),
        onSiteChanged: (_) => reportedCount++,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Assign Blue Hole'));
    await tester.pump();

    // Tear the card down, then let the write complete.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pumpAndSettle();
    blocking.gate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(reportedCount, 0, reason: 'no setState into a disposed host');
    expect(refreshed, 0, reason: 'no ref use after dispose');
  });
}
