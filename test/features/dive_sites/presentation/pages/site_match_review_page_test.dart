import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_match_review_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _SeededNotifier extends SiteMatchReviewNotifier {
  _SeededNotifier(Ref ref, SiteMatchReviewState seeded)
    : super(ref, null, autoInit: false) {
    state = seeded;
  }
}

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

Widget _harness(SiteMatchReviewState seeded) => ProviderScope(
  overrides: [
    // The embedded map reads the tile style from settingsProvider.
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    siteMatchReviewProvider(
      null,
    ).overrideWith((ref) => _SeededNotifier(ref, seeded)),
  ],
  child: const MaterialApp(
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
}
