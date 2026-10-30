import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_caption_text.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  const sam = NodeRef(ConnectionKind.buddy, 'sam');
  const graph = ConnectionGraph(
    nodes: [ConnectionNode(ref: sam, label: 'Sam', diveCount: 3)],
    edges: [],
  );
  const thicker = 'Thicker lines mean more dives.';

  ConnectionsCaptionText caption(
    ConnectionsViewState view, {
    EdgeMode edges = EdgeMode.weighted,
    Map<String, String> saved = const {},
  }) => ConnectionsCaptionText.of(
    l10n: l10n,
    view: view,
    graph: graph,
    edges: edges,
    savedMapNames: saved,
  );

  test('the start names its map and says how to read a line', () {
    final c = caption(ConnectionsViewState.initial);
    expect(c.title, 'Who dives where');
    expect(
      c.sentence,
      'A line means you dived at that site with that buddy. $thicker',
    );
  });

  test('thin lines drop the weight clause; selected-only keeps it', () {
    final start = ConnectionsViewState.initial;
    expect(
      caption(start, edges: EdgeMode.thin).sentence,
      isNot(contains('Thicker')),
    );
    expect(
      caption(start, edges: EdgeMode.selectedOnly).sentence,
      endsWith(thicker),
    );
  });

  test('an edited map is a custom map', () {
    final start = ConnectionsViewState.initial;
    final c = caption(start.editMap(start.mapSpec));
    expect(c.title, 'Custom map');
    expect(
      c.sentence,
      startsWith('Buddies, Sites; a line means they share a dive.'),
    );
    final withTrips = caption(
      start.editMap(start.mapSpec.withKind(ConnectionKind.trip)),
    );
    expect(withTrips.sentence, startsWith('Buddies, Sites, Trips; '));
  });

  test('a saved map is named and read like a custom one', () {
    final start = ConnectionsViewState.initial;
    final c = caption(
      start.applySavedMap('m1', start.mapSpec),
      saved: {'m1': 'Fiji 2024'},
    );
    expect(c.title, 'Fiji 2024');
    expect(c.sentence, startsWith('Buddies, Sites; a line means'));
  });

  test('Around mode names the centre and its reach', () {
    final one = caption(ConnectionsViewState.initial.centreOn(sam));
    expect(one.title, 'Around Sam');
    expect(
      one.sentence,
      startsWith('Everything that shares a dive with this centre.'),
    );
    final two = caption(ConnectionsViewState.initial.centreOn(sam).withHops(2));
    expect(two.sentence, contains('within 2 steps'));
  });

  test('every preset has its own sentence', () {
    final custom = caption(
      ConnectionsViewState.initial.editMap(
        ConnectionsViewState.initial.mapSpec,
      ),
    ).sentence;
    final seen = <String>{};
    for (final p in ConnectionPresets.all) {
      final s = caption(ConnectionsViewState.initial.applyPreset(p)).sentence;
      expect(s, isNot(custom), reason: p.id);
      expect(seen.add(s), isTrue, reason: '${p.id} repeats another preset');
    }
  });
}
