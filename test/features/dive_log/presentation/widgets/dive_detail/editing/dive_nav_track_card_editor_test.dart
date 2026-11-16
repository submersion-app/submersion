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
}
