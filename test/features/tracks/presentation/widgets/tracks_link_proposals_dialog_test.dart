import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_matcher.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_link_proposals_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

NavTrack _route(String id, {String? name, String? sourceRef}) => NavTrack(
  id: id,
  name: name,
  sourceRef: sourceRef,
  source: NavTrackSource.seacraftEnc,
  startTime: DateTime.utc(2026, 11, 14, 9, 12).millisecondsSinceEpoch,
  endTime: DateTime.utc(2026, 11, 14, 10).millisecondsSinceEpoch,
  pointCount: 2,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Dive _dive(String id, int number, {DiveSite? site}) => Dive(
  id: id,
  diveNumber: number,
  dateTime: DateTime.utc(2026, 11, 14, 9),
  entryTime: DateTime.utc(2026, 11, 14, 9),
  site: site,
);

final List<NavTrackLinkProposal> _proposals = [
  (
    route: _route('r1', name: 'Morning run'),
    dive: _dive(
      'd1',
      212,
      site: const DiveSite(id: 's1', name: 'Blue Hole'),
    ),
  ),
  (route: _route('r2', sourceRef: 'ENC_0042.csv'), dive: _dive('d2', 213)),
];

/// Opens the dialog from a button and records what it answered.
Future<List<bool>> _open(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  final answers = <bool>[];
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: base,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => answers.add(
                await showTracksLinkProposalsDialog(context, _proposals),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return answers;
}

void main() {
  testWidgets('lists each track with the dive and site it would link to', (
    tester,
  ) async {
    await _open(tester);

    expect(find.text('Link 2 underwater tracks?'), findsOneWidget);
    expect(
      find.text('Each of these tracks overlaps exactly one dive in time.'),
      findsOneWidget,
    );
    expect(find.text('Morning run'), findsOneWidget);
    expect(find.textContaining('Dive #212 · Blue Hole'), findsOneWidget);
    // No name: the file it came from; no site: the dive alone.
    expect(find.text('ENC_0042.csv'), findsOneWidget);
    expect(find.textContaining(RegExp(r'Dive #213$')), findsOneWidget);
  });

  testWidgets('Link answers true', (tester) async {
    final answers = await _open(tester);
    await tester.tap(find.text('Link'));
    await tester.pumpAndSettle();
    expect(answers, [true]);
  });

  testWidgets('Not now answers false', (tester) async {
    final answers = await _open(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(answers, [false]);
  });

  testWidgets('dismissing answers false', (tester) async {
    final answers = await _open(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(answers, [false]);
  });

  testWidgets('dates the recording in the locale\'s own words', (tester) async {
    await _open(tester, locale: const Locale('de'));
    expect(find.textContaining(' um '), findsNWidgets(2));
  });
}
