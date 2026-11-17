import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_assignment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_suggestion_card.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_suggestion_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../media/presentation/support/media_widget_harness.dart';
import '../support/fake_matching_service.dart';
import '../../../../helpers/fake_hosts.dart';

/// Notes when the logbook rules run, and changes nothing.
class _RecordingEngine extends RuleEngine {
  _RecordingEngine(this.order) : super(names: (_) async => NameIndex(const []));

  final List<String> order;

  @override
  Future<RuleRunResult> run(RuleRunRequest request) async {
    order.add('rules');
    return RuleRunResult.noRules;
  }
}

/// Records the coordinates a held change writes instead of storing them.
/// Records the locations asked of it and stores them, unless [declines]:
/// a shared library site this profile may not edit takes no write, and
/// says nothing.
class _RecordingSites extends SiteRepository {
  _RecordingSites({this.declines = false});

  final bool declines;
  final located = <String>[];
  final _stored = <String, GeoPoint>{};

  @override
  Future<void> updateSiteCoordinates(
    String siteId,
    GeoPoint location, {
    double? altitude,
  }) async {
    located.add(siteId);
    if (!declines) _stored[siteId] = location;
  }

  @override
  Future<DiveSite?> getSiteById(String id) async =>
      DiveSite(id: id, name: id, location: _stored[id]);
}

class _StubDiveRepository implements DiveRepository {
  final dismissed = <String>[];

  @override
  Future<void> setSiteSuggestionDismissed(String diveId, bool value) async {
    if (value) dismissed.add(diveId);
  }

  @override
  Future<Dive?> getDiveById(String id) async =>
      Dive(id: id, diveNumber: 1, dateTime: DateTime(2026, 1, 1), maxDepth: 18);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // The code under test calls Nominatim; it answers as offline, as it
  // would on a device without a network.
  setUp(() {
    serveFakeHost('nominatim.openstreetmap.org');
  });

  late FakeMatchingService service;
  late _StubDiveRepository dives;

  setUp(() {
    service = FakeMatchingService();
    dives = _StubDiveRepository();
  });

  Future<Widget> host(
    SiteSuggestion? suggestion, {
    DiveSite? currentSite,
    List<String>? rulesLog,
    SiteSuggestionEditing editing = const SiteSuggestionLocked(),
    ValueListenable<bool>? cardShown,
    List<Override> extra = const [],
  }) => mediaTestApp(
    overrides: [
      ...extra,
      siteSuggestionForDiveProvider(
        'd1',
      ).overrideWith((ref) async => suggestion),
      diveRepositoryProvider.overrideWithValue(dives),
      // A site the card creates runs the logbook rules inside its write;
      // these tests have no database for the real engine.
      ruleEngineProvider.overrideWithValue(_RecordingEngine(rulesLog ?? [])),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
      // A site picked in a sitting reads what dive types it stands for.
      siteTypesForSiteProvider.overrideWith((ref, id) async => const []),
      diveTypesProvider.overrideWith((ref) async => const []),
    ],
    home: Scaffold(
      body: Builder(
        builder: (context) {
          final card = SiteSuggestionCard(
            diveId: 'd1',
            currentSite: currentSite,
            editing: editing,
          );
          // A test can take the card away while its write runs.
          if (cardShown == null) return card;
          return ValueListenableBuilder<bool>(
            valueListenable: cardShown,
            builder: (context, shown, _) =>
                shown ? card : const SizedBox.shrink(),
          );
        },
      ),
    ),
  );

  testWidgets('renders nothing when there is no suggestion', (tester) async {
    await tester.pumpWidget(await host(null));
    await tester.pumpAndSettle();
    expect(find.byType(SiteSuggestionCard), findsOneWidget);
    expect(find.textContaining('Location'), findsNothing);
  });

  // Locked, the card follows the dive as stored: it hides whenever the site
  // the page shows disagrees with the suggestion's.
  testWidgets('hides when the page shows a located site', (tester) async {
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

  testWidgets('hides when the page shows a site the dive was not saved with', (
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

  // The dive page offers unlock-to-edit (issue #4527, plan 4).
  group('on a locked page', () {
    final clear = suggestionFor(
      FakeMatchingService(),
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

    testWidgets('it is shown, and every button and its close are disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        await host(clear, editing: const SiteSuggestionLocked()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Assign Blue Hole'), findsOneWidget);
      final live = find.byWidgetPredicate(
        (w) =>
            (w is ButtonStyleButton && w.onPressed != null) ||
            (w is IconButton && w.onPressed != null),
      );
      expect(live, findsNothing);
      await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(dives.dismissed, isEmpty);
    });

    testWidgets('it is as tall as in a sitting', (tester) async {
      final session = EditSession<Dive>(
        Dive(id: 'd1', diveNumber: 1, dateTime: DateTime(2026, 1, 1)),
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        await host(clear, editing: SiteSuggestionSitting(session)),
      );
      await tester.pumpAndSettle();
      final open = tester.getSize(find.byType(SiteSuggestionCard)).height;

      await tester.pumpWidget(
        await host(clear, editing: const SiteSuggestionLocked()),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(SiteSuggestionCard)).height, open);
    });
  });

  group('during a sitting', () {
    final bare = Dive(
      id: 'd1',
      diveNumber: 1,
      dateTime: DateTime(2026, 1, 1),
      maxDepth: 18,
    );
    const bareSite = DiveSite(id: 'bare', name: 'Typed Twice');
    late EditSession<Dive> session;

    SiteSuggestion assignable(FakeMatchingService on) => suggestionFor(
      on,
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

    setUp(() => session = EditSession(bare));

    testWidgets('assign puts the site in the sitting and writes no link', (
      tester,
    ) async {
      service.resolvesTo['s1'] = const DiveSite(id: 's1', name: 'Blue Hole');
      await tester.pumpWidget(
        await host(
          assignable(service),
          editing: SiteSuggestionSitting(session),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Assign Blue Hole'));
      await tester.pumpAndSettle();

      expect(service.resolved.single.candidateId, 's1');
      expect(service.applied, isEmpty);
      expect(session.valueOf(diveSiteField)?.id, 's1');
    });

    testWidgets('assigning a catalogue site runs the new site\'s rules', (
      tester,
    ) async {
      final log = <String>[];
      service.resolvesTo['s1'] = const DiveSite(id: 'new', name: 'Blue Hole');
      service.createdBy['s1'] = const ['new'];
      await tester.pumpWidget(
        await host(
          assignable(service),
          editing: SiteSuggestionSitting(session),
          rulesLog: log,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Assign Blue Hole'));
      await tester.pumpAndSettle();

      expect(log, ['rules']);
      expect(session.valueOf(diveSiteField)?.id, 'new');
    });

    testWidgets('add location is held as a change of the header', (
      tester,
    ) async {
      session = EditSession(bare.copyWith(site: bareSite));
      await tester.pumpWidget(
        await host(
          suggestionFor(service, site: bareSite),
          currentSite: bareSite,
          editing: SiteSuggestionSitting(session),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Add location to Typed Twice'));
      await tester.pumpAndSettle();

      expect(session.isHeld(siteLocationChangeKey('bare')), isTrue);
      expect(session.changedCardIds, {diveHeaderCardId});
      expect(service.applied, isEmpty);
      expect(find.textContaining('Add location'), findsNothing);
    });

    // The immediate path looks the site's altitude up once its location is
    // written. A held location is written at Save, inside its transaction,
    // so it notes the site for that lookup, made after the commit
    // (issue #4527).
    testWidgets('a held location, once written, notes its site for the '
        'altitude lookup', (tester) async {
      final sites = _RecordingSites();
      session = EditSession(bare.copyWith(site: bareSite));
      await tester.pumpWidget(
        await host(
          suggestionFor(service, site: bareSite),
          currentSite: bareSite,
          editing: SiteSuggestionSitting(session),
          extra: [siteRepositoryProvider.overrideWithValue(sites)],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Add location to Typed Twice'));
      await tester.pumpAndSettle();
      expect(sitesLocatedInSave(session), isEmpty);

      await session.runHeldWrites();

      expect(sites.located, ['bare']);
      expect(sitesLocatedInSave(session).keys, ['bare']);
    });

    // Copilot's review of PR #4670: a library site this profile may not
    // edit declines the location without a word, and a site that did not
    // take it has no altitude or tide to work out there.
    testWidgets('a held location the site declined notes nothing', (
      tester,
    ) async {
      final sites = _RecordingSites(declines: true);
      session = EditSession(bare.copyWith(site: bareSite));
      await tester.pumpWidget(
        await host(
          suggestionFor(service, site: bareSite),
          currentSite: bareSite,
          editing: SiteSuggestionSitting(session),
          extra: [siteRepositoryProvider.overrideWithValue(sites)],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Add location to Typed Twice'));
      await tester.pumpAndSettle();

      await session.runHeldWrites();

      expect(sites.located, ['bare']);
      expect(sitesLocatedInSave(session), isEmpty);
    });

    testWidgets('dismiss is held, and the dive is not written', (tester) async {
      await tester.pumpWidget(
        await host(
          suggestionFor(service, status: ProposalStatus.none),
          editing: SiteSuggestionSitting(session),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(session.isHeld(siteSuggestionDismissKey), isTrue);
      expect(dives.dismissed, isEmpty);
      expect(find.text('Create Site'), findsNothing);
    });

    testWidgets('create makes the site at once and holds the link', (
      tester,
    ) async {
      await tester.pumpWidget(
        await host(
          suggestionFor(service, status: ProposalStatus.none),
          editing: SiteSuggestionSitting(session),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Site'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Wall');
      await tester.tap(find.widgetWithText(FilledButton, 'Create Site').last);
      await tester.pumpAndSettle();

      expect(service.createdUnlinked.single.name, 'Wall');
      expect(service.created, isEmpty);
      expect(session.valueOf(diveSiteField)?.id, 'made');
    });

    testWidgets('with the header open an assigned suggestion stays, '
        'disabled', (tester) async {
      service.resolvesTo['s1'] = const DiveSite(id: 's1', name: 'Blue Hole');
      await tester.pumpWidget(
        await host(
          assignable(service),
          editing: SiteSuggestionSitting(session, layout: bare),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Assign Blue Hole'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Assign Blue Hole'), findsOneWidget);
      final live = find.byWidgetPredicate(
        (w) => w is ButtonStyleButton && w.onPressed != null,
      );
      expect(live, findsNothing);
    });

    // Final review, minor 4: the page must not jump while it saves.
    testWidgets('while the sitting is saved the card stays, disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        await host(
          assignable(service),
          editing: SiteSuggestionSitting(session),
        ),
      );
      await tester.pumpAndSettle();

      session.freeze();
      await tester.pumpWidget(
        await host(
          assignable(service),
          editing: SiteSuggestionSitting(session),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Assign Blue Hole'), findsOneWidget);
      final live = find.byWidgetPredicate(
        (w) => w is ButtonStyleButton && w.onPressed != null,
      );
      expect(live, findsNothing);
    });

    testWidgets('a site that comes back after Cancel sets nothing', (
      tester,
    ) async {
      final blocking = _BlockingResolveService();
      await tester.pumpWidget(
        await host(
          assignable(blocking),
          editing: SiteSuggestionSitting(session),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Assign Blue Hole'));
      await tester.pump();
      session.dispose();
      blocking.gate.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(session.valueOf(diveSiteField), isNull);
    });

    // Code review: the pick is the sitting's own work, so Save waits for
    // it, and one tap is one resolve.
    testWidgets('Save waits for an assign that is still resolving', (
      tester,
    ) async {
      final blocking = _BlockingResolveService();
      await tester.pumpWidget(
        await host(
          assignable(blocking),
          editing: SiteSuggestionSitting(session),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Assign Blue Hole'));
      await tester.pump();
      expect(session.isSettled, isFalse);

      blocking.gate.complete();
      await tester.pumpAndSettle();
      expect(session.isSettled, isTrue);
      expect(session.valueOf(diveSiteField)?.id, 's1');
    });

    testWidgets('a second tap while the first resolves does nothing', (
      tester,
    ) async {
      final blocking = _BlockingResolveService();
      await tester.pumpWidget(
        await host(
          assignable(blocking),
          editing: SiteSuggestionSitting(session),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Assign Blue Hole'));
      await tester.pump();
      await tester.tap(find.textContaining('Assign Blue Hole'));
      await tester.pump();
      blocking.gate.complete();
      await tester.pumpAndSettle();

      expect(blocking.resolved, hasLength(1));
    });

    testWidgets('a failure after the card has gone still says so', (
      tester,
    ) async {
      final blocking = _BlockingResolveService()
        ..failWith = StateError('offline');
      final cardShown = ValueNotifier(true);
      addTearDown(cardShown.dispose);
      await tester.pumpWidget(
        await host(
          assignable(blocking),
          editing: SiteSuggestionSitting(session),
          cardShown: cardShown,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Assign Blue Hole'));
      await tester.pump();
      cardShown.value = false;
      await tester.pump();
      blocking.gate.complete();
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l10n.siteMatchReview_applyError), findsOneWidget);
    });

    testWidgets('a failure says so and sets nothing', (tester) async {
      service.failWith = StateError('offline');
      await tester.pumpWidget(
        await host(
          assignable(service),
          editing: SiteSuggestionSitting(session),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Assign Blue Hole'));
      await tester.pumpAndSettle();

      expect(session.isDirty, isFalse);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SiteSuggestionCard)),
      );
      expect(find.text(l10n.siteMatchReview_applyError), findsOneWidget);
    });
  });
}

/// Holds a resolve open so the test can end the sitting mid-write.
class _BlockingResolveService extends FakeMatchingService {
  final gate = Completer<void>();

  @override
  Future<({DiveSite site, List<String> createdSiteIds})> resolveCandidate(
    String diveId,
    String candidateId,
  ) async {
    await gate.future;
    return super.resolveCandidate(diveId, candidateId);
  }
}
