import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';

void main() {
  final base = ConnectionsViewState.initial;

  test('the around location carries the mode and the focus', () {
    expect(
      connectionsAroundLocation(const NodeRef(ConnectionKind.site, 's1')),
      '/insights/connections?mode=around&focus=site:s1',
    );
  });

  test('empty args change nothing', () {
    final args = ConnectionsRouteArgs.fromQuery(const {});
    expect(args.isEmpty, isTrue);
    expect(args.apply(base), base);
  });

  test('mode=around&focus centres the view', () {
    final s = ConnectionsRouteArgs.fromQuery(const {
      'mode': 'around',
      'focus': 'diveCenter:c1',
      'hops': '2',
    }).apply(base);
    expect(s.mode, ConnectionsMode.around);
    expect(s.focus, const NodeRef(ConnectionKind.diveCenter, 'c1'));
    expect(s.hops, 2);
  });

  test('a preset applies a map', () {
    final s = ConnectionsRouteArgs.fromQuery(const {
      'mode': 'map',
      'preset': 'travel',
    }).apply(base.centreOn(const NodeRef(ConnectionKind.buddy, 'x')));
    expect(s.mode, ConnectionsMode.map);
    expect(s.presetId, 'travel');
  });

  test('phase 1 links keep working', () {
    final lens = ConnectionsRouteArgs.fromQuery(const {
      'lens': 'where',
      'focus': 'buddy:jane',
    }).apply(base);
    expect(lens.presetId, 'where');
    expect(lens.focus, const NodeRef(ConnectionKind.buddy, 'jane'));
    expect(lens.mode, ConnectionsMode.around);
    final pair = ConnectionsRouteArgs.fromQuery(const {
      'a': 'equipment',
      'b': 'trip',
    }).apply(base);
    expect(pair.mapSpec.links, {
      KindLink(ConnectionKind.equipment, ConnectionKind.trip),
    });
  });

  test('garbage values are ignored', () {
    final s = ConnectionsRouteArgs.fromQuery(const {
      'mode': 'sideways',
      'preset': 'nope',
      'focus': 'unicorn:1',
      'hops': 'many',
    }).apply(base);
    expect(s, base);
  });

  test('a phase 1 pair link does not mark the preset edited', () {
    final pair = ConnectionsRouteArgs.fromQuery(const {
      'a': 'equipment',
      'b': 'trip',
    }).apply(base);
    expect(pair.editedFromPresetId, isNull);
    expect(pair.presetId, isNull);
  });

  test('an old /connections link moves under Insights with its query', () {
    expect(
      connectionsLegacyRedirect(
        Uri.parse('/connections?lens=circle&focus=buddy:jane'),
      ),
      '/insights/connections?lens=circle&focus=buddy:jane',
    );
    expect(
      connectionsLegacyRedirect(Uri.parse('/connections')),
      '/insights/connections',
    );
  });
}
