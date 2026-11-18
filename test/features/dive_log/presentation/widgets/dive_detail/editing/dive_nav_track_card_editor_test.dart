import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_nav_track_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_route_links_sitting.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

import '../../../../../../helpers/l10n_test_helpers.dart';
import '../../../../../../helpers/nav_track_fixtures.dart';

class _Repo extends NavTrackRepository {
  _Repo(this.linked);
  final List<NavTrack> linked;

  @override
  Future<List<NavTrack>> getForDive(
    String diveId, {
    bool includePoints = false,
  }) async => linked;
}

/// Answers the route read when the test says.
class _GatedRepo extends NavTrackRepository {
  _GatedRepo(this.answer);
  final Future<List<NavTrack>> answer;

  @override
  Future<List<NavTrack>> getForDive(
    String diveId, {
    bool includePoints = false,
  }) => answer;
}

/// Fails its first read, then answers.
class _FailingOnceRepo extends _Repo {
  _FailingOnceRepo(super.linked);
  var reads = 0;

  @override
  Future<List<NavTrack>> getForDive(
    String diveId, {
    bool includePoints = false,
  }) async {
    if (reads++ == 0) throw StateError('database closed');
    return linked;
  }
}

/// The Underwater track card's editor picks the primary route in the
/// sitting (issue #4527, plan 6).
void main() {
  final a = testNavTrack('a', diveId: 'd1');
  final b = testNavTrack('b', diveId: 'd1', isPrimary: false);
  final dive = Dive(id: 'd1', dateTime: DateTime.utc(2026));

  testWidgets('"Make primary" sits under the title, the tag in the '
      'subtitle, and a tap holds the pick', (tester) async {
    final container = ProviderContainer(
      overrides: [
        navTrackRepositoryProvider.overrideWithValue(_Repo([a, b])),
      ],
    );
    addTearDown(container.dispose);
    final session = EditSession<Dive>(dive);
    addTearDown(session.dispose);
    loadDiveRouteLinks(session, container.read);
    await tester.runAsync(session.settled);

    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: Scaffold(body: DiveNavTrackCardEditor(session: session)),
      ),
    );
    await tester.pump();

    // A longer translation squeezes the title when text sits in trailing.
    for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) {
      expect(tile.trailing, isNot(isA<TextButton>()));
      expect(tile.trailing, isNot(isA<Text>()));
    }
    final bTile = find.byKey(const ValueKey('nav-track-primary-b'));
    final action = find.descendant(
      of: bTile,
      matching: find.byType(TileSubtitleAction),
    );
    expect(action, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('nav-track-primary-a')),
        matching: find.text('primary'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: action, matching: find.text('Make primary')),
    );
    await tester.pump();
    expect(sittingRouteDraft(session)?.primaryId, 'b');
    expect(session.changedCardIds, {'navTrack'});
  });

  testWidgets('a read that failed says so, and Try again reads the routes', (
    tester,
  ) async {
    final repo = _FailingOnceRepo([a]);
    final container = ProviderContainer(
      overrides: [navTrackRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final session = EditSession<Dive>(dive);
    addTearDown(session.dispose);
    loadDiveRouteLinks(session, container.read);
    await tester.runAsync(session.settled);

    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: Scaffold(body: DiveNavTrackCardEditor(session: session)),
      ),
    );
    await tester.pump();
    expect(find.byType(SittingLoadFailed), findsOneWidget);
    expect(find.byKey(const ValueKey('dive-edit-route-row')), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.runAsync(session.settled);
    await tester.pump();

    expect(repo.reads, 2);
    expect(find.byType(SittingLoadFailed), findsNothing);
    expect(sittingRouteDraft(session)?.current.single.id, 'a');
    expect(find.byKey(const ValueKey('dive-edit-route-row')), findsOneWidget);
  });

  testWidgets('opened while the routes are read, it shows them once they '
      'are', (tester) async {
    final reading = Completer<List<NavTrack>>();
    final container = ProviderContainer(
      overrides: [
        navTrackRepositoryProvider.overrideWithValue(
          _GatedRepo(reading.future),
        ),
      ],
    );
    addTearDown(container.dispose);
    final session = EditSession<Dive>(dive);
    addTearDown(session.dispose);
    loadDiveRouteLinks(session, container.read);

    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: Scaffold(body: DiveNavTrackCardEditor(session: session)),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('nav-track-primary-b')), findsNothing);

    reading.complete([a, b]);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('nav-track-primary-b')), findsOneWidget);
  });
}
