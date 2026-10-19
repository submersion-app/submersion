import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_match_review_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../media/presentation/support/fake_location_service.dart';

class _SeededNotifier extends SiteMatchReviewNotifier {
  _SeededNotifier(
    Ref ref,
    SiteMatchReviewState seeded, {
    this.confirmResult,
    this.createGate,
  }) : super(ref, null, autoInit: false) {
    state = seeded;
  }

  final ApplyResult? confirmResult;

  /// Holds Create site here open until completed, when given.
  final Completer<void>? createGate;
  final createdHere = <(String, DiveSite)>[];

  @override
  Future<ApplyResult?> confirm() async => confirmResult;

  @override
  Future<DiveSite?> createSiteHere(String diveId, DiveSite site) async {
    await createGate?.future;
    createdHere.add((diveId, site));
    // As the real notifier: a page left meanwhile still gets the site.
    if (!mounted) return site.copyWith(id: 'created');
    state = state.copyWith(
      proposals: [
        for (final p in state.proposals)
          if (p.dive.id != diveId) p,
      ],
    );
    return site.copyWith(id: 'created');
  }
}

late _SeededNotifier _notifier;

Dive _dive(int n) => Dive(
  id: 'd$n',
  diveNumber: n,
  dateTime: DateTime(2026, 1, 1),
  maxDepth: 18,
  entryLocation: const GeoPoint(0, 0),
);

MatchCandidateView _cand(String id, {bool existing = true}) =>
    MatchCandidateView(
      id: id,
      name: 'Site $id',
      isExisting: existing,
      distanceMeters: 42,
      location: const GeoPoint(0, 0.0003),
      maxDepth: 30,
      region: 'Red Sea',
    );

Widget _harness(SiteMatchReviewState seeded, {ApplyResult? confirmResult}) =>
    ProviderScope(
      overrides: [
        // The embedded map reads the tile style from settingsProvider.
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        siteMatchReviewProvider(null).overrideWith(
          (ref) => _notifier = _SeededNotifier(
            ref,
            seeded,
            confirmResult: confirmResult,
          ),
        ),
        locationServiceProvider.overrideWithValue(
          FakeLocationService(const PlaceLookup.empty()),
        ),
      ],
      child: const MaterialApp(
        // Same reason as elsewhere: these tests assert English strings.
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SiteMatchReviewPage(),
      ),
    );

void main() {
  testWidgets('loading shows progress', (tester) async {
    await tester.pumpWidget(_harness(const SiteMatchReviewState()));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('renders summary, confirm bar, and focused candidates', (
    tester,
  ) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.clear,
          candidates: [_cand('s1')],
          recommendedCandidateId: 's1',
        ),
      ],
      focusedDiveId: 'd7',
      selections: const {'d7': 's1'},
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();

    expect(find.textContaining('1 selected'), findsOneWidget);
    expect(find.textContaining('Confirm 1'), findsOneWidget);
    expect(find.text('Site s1'), findsWidgets);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('confirm disabled when nothing selected', (tester) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(3),
          status: ProposalStatus.review,
          candidates: [_cand('a'), _cand('b')],
        ),
      ],
      focusedDiveId: 'd3',
      selections: const {},
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();

    expect(find.textContaining('0 selected'), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm 0 matches'),
    );
    expect(confirm.onPressed, isNull);
  });

  testWidgets('no-match dive shows no nearby site', (tester) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [MatchProposal(dive: _dive(9), status: ProposalStatus.none)],
      focusedDiveId: 'd9',
      selections: const {},
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();
    expect(find.text('No nearby site'), findsOneWidget);
  });

  testWidgets('cancel with selections prompts to discard', (tester) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.clear,
          candidates: [_cand('s1')],
          recommendedCandidateId: 's1',
        ),
      ],
      focusedDiveId: 'd7',
      selections: const {'d7': 's1'},
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard matches?'), findsOneWidget);
  });

  testWidgets('wide layout shows list and detail side by side', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1100, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.clear,
          candidates: [_cand('s1')],
          recommendedCandidateId: 's1',
        ),
      ],
      focusedDiveId: 'd7',
      selections: const {'d7': 's1'},
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();

    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(find.text('Site s1'), findsWidgets);
  });

  testWidgets('narrow layout stacks map over inline cards', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.clear,
          candidates: [_cand('s1')],
          recommendedCandidateId: 's1',
        ),
      ],
      focusedDiveId: 'd7',
      selections: const {'d7': 's1'},
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();

    expect(find.byType(VerticalDivider), findsNothing); // stacked
    expect(find.text('Site s1'), findsWidgets); // inline card under focused row
  });

  testWidgets('confirm success shows the result snackbar', (tester) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.clear,
          candidates: [_cand('s1')],
          recommendedCandidateId: 's1',
        ),
      ],
      focusedDiveId: 'd7',
      selections: const {'d7': 's1'},
    );
    await tester.pumpWidget(
      _harness(
        seeded,
        confirmResult: const ApplyResult(divesLinked: 2, sitesCreated: 1),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm 1 matches'));
    await tester.pump();
    expect(find.textContaining('Linked 2 dives'), findsOneWidget);
  });

  testWidgets('confirm leaves at once while the new sites\' rules run', (
    tester,
  ) async {
    // The rules never finish here. Waiting on them kept the page up with
    // Confirm live again, and a second tap made every new site twice.
    final names = Completer<NameIndex>();
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.clear,
          candidates: [_cand('s1', existing: false)],
          recommendedCandidateId: 's1',
        ),
      ],
      focusedDiveId: 'd7',
      selections: const {'d7': 's1'},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          siteMatchReviewProvider(null).overrideWith(
            (ref) => _notifier = _SeededNotifier(
              ref,
              seeded,
              confirmResult: const ApplyResult(
                divesLinked: 1,
                sitesCreated: 1,
                createdSiteIds: ['new'],
              ),
            ),
          ),
          locationServiceProvider.overrideWithValue(
            FakeLocationService(const PlaceLookup.empty()),
          ),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          ruleEngineProvider.overrideWithValue(
            RuleEngine(names: (_) => names.future),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SiteMatchReviewPage(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm 1 matches'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SiteMatchReviewPage), findsNothing);
  });

  testWidgets('confirm failure shows the error snackbar', (tester) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.clear,
          candidates: [_cand('s1')],
          recommendedCandidateId: 's1',
        ),
      ],
      focusedDiveId: 'd7',
      selections: const {'d7': 's1'},
    );
    await tester.pumpWidget(_harness(seeded)); // confirmResult == null
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm 1 matches'));
    await tester.pump();
    expect(find.textContaining("Couldn't apply"), findsOneWidget);
  });

  testWidgets('rich card shows rating, difficulty, features, description', (
    tester,
  ) async {
    const rich = MatchCandidateView(
      id: 's1',
      name: 'Blue Hole',
      isExisting: true,
      distanceMeters: 42,
      location: GeoPoint(0, 0.0003),
      minDepth: 5,
      maxDepth: 40,
      region: 'Dahab',
      rating: 4.5,
      difficulty: 'Advanced',
      features: ['wreck'],
      description: 'Deep blue hole.',
    );
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.clear,
          candidates: [rich],
          recommendedCandidateId: 's1',
        ),
      ],
      focusedDiveId: 'd7',
      selections: const {'d7': 's1'},
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();

    expect(find.textContaining('Advanced'), findsWidgets);
    expect(find.text('wreck'), findsOneWidget);
    expect(find.text('Deep blue hole.'), findsOneWidget);
  });

  testWidgets('tapping a candidate card selects it', (tester) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(3),
          status: ProposalStatus.review,
          candidates: [_cand('a'), _cand('b')],
        ),
      ],
      focusedDiveId: 'd3',
      selections: const {},
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();
    expect(find.textContaining('0 selected'), findsOneWidget);

    await tester.tap(find.text('Site a').first);
    await tester.pump();
    expect(find.textContaining('1 selected'), findsOneWidget);
  });

  testWidgets('photo-sourced proposals show the source chip', (tester) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.clear,
          candidates: [_cand('s1')],
          recommendedCandidateId: 's1',
          point: const GeoPoint(0, 0),
          pointSource: PointSource.photo,
        ),
      ],
      focusedDiveId: 'd7',
      selections: const {'d7': 's1'},
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();
    expect(find.text('from photo'), findsOneWidget);
  });

  testWidgets('the current-site candidate is labelled and preselected', (
    tester,
  ) async {
    final current = MatchCandidateView(
      id: SiteMatchingService.currentSiteCandidateId('bare'),
      name: 'Typed Twice',
      isExisting: true,
      isCurrentSite: true,
      distanceMeters: 0,
      location: const GeoPoint(0, 0),
    );
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.clear,
          candidates: [current],
          recommendedCandidateId: current.id,
          point: const GeoPoint(0, 0),
        ),
      ],
      focusedDiveId: 'd7',
      selections: {'d7': current.id},
    );
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();
    expect(find.text('Add location to this site'), findsOneWidget);
    expect(find.text('Typed Twice'), findsWidgets);
    expect(find.textContaining('0 m away'), findsNothing);
  });

  testWidgets('Create site here opens the dialog and links immediately', (
    tester,
  ) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.none,
          point: const GeoPoint(0, 0),
        ),
      ],
      focusedDiveId: 'd7',
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();
    await tester.tap(find.text('Create site here'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Wall');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Site'));
    await tester.pumpAndSettle();
    expect(_notifier.createdHere.single.$1, 'd7');
    expect(_notifier.createdHere.single.$2.name, 'Wall');
    expect(find.textContaining('Created site: Wall'), findsOneWidget);
    expect(find.text('Nothing to match.'), findsOneWidget);
  });

  testWidgets('a site created here gets its rules though the page is left', (
    tester,
  ) async {
    // The site exists whether or not the diver waited on this page, so it
    // gets its "after creating a site by hand" rules either way.
    final gate = Completer<void>();
    final engine = _RecordingEngine();
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.none,
          point: const GeoPoint(0, 0),
        ),
      ],
      focusedDiveId: 'd7',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          siteMatchReviewProvider(null).overrideWith(
            (ref) => _notifier = _SeededNotifier(ref, seeded, createGate: gate),
          ),
          locationServiceProvider.overrideWithValue(
            FakeLocationService(const PlaceLookup.empty()),
          ),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          ruleEngineProvider.overrideWithValue(engine),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SiteMatchReviewPage(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create site here'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Wall');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Site'));
    await tester.pumpAndSettle();

    // The diver leaves while the site is still being made.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SiteMatchReviewPage), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();

    expect(engine.requests.single.targets, {
      RuleSubject.sites: {'created'},
    });
  });

  testWidgets('confirm snackbar reports located sites', (tester) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.clear,
          candidates: [_cand('s1')],
          recommendedCandidateId: 's1',
          point: const GeoPoint(0, 0),
        ),
      ],
      focusedDiveId: 'd7',
      selections: const {'d7': 's1'},
    );
    await tester.pumpWidget(
      _harness(
        seeded,
        confirmResult: const ApplyResult(
          divesLinked: 1,
          sitesCreated: 0,
          sitesLocated: 1,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm 1 matches'));
    await tester.pump();
    expect(find.textContaining('located 1 sites'), findsOneWidget);
  });
}

/// Notes each rules run it is asked for, changing nothing.
class _RecordingEngine extends RuleEngine {
  _RecordingEngine() : super(names: (_) async => NameIndex(const []));

  final requests = <RuleRunRequest>[];

  @override
  Future<RuleRunResult> run(RuleRunRequest request) async {
    requests.add(request);
    return RuleRunResult.noRules;
  }
}
