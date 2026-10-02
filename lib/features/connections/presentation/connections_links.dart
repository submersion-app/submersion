import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';

/// The explorer's route segment under `/insights`; the router's route and
/// every link are built from it, so they cannot drift apart.
const kConnectionsSegment = 'connections';

/// Where the Connections explorer lives: a full page in the Insights area.
const kConnectionsLocation = '/insights/$kConnectionsSegment';

/// The deep link every detail page's "Open in Connections" pushes.
String connectionsAroundLocation(NodeRef ref) =>
    '$kConnectionsLocation?mode=around&focus=${ref.wire}';

/// Maps a link to the old top-level `/connections` route onto the page's
/// place under Insights, keeping its query.
String connectionsLegacyRedirect(Uri uri) =>
    uri.hasQuery ? '$kConnectionsLocation?${uri.query}' : kConnectionsLocation;

/// [kConnectionsLocation] query parameters. Revision 2 uses `mode`, `preset`,
/// `focus` and `hops`; phase 1's `lens`, `a` and `b` stay accepted.
class ConnectionsRouteArgs {
  const ConnectionsRouteArgs({
    this.mode,
    this.preset,
    this.focus,
    this.hops,
    this.lens,
    this.a,
    this.b,
  });

  factory ConnectionsRouteArgs.fromQuery(Map<String, String> q) =>
      ConnectionsRouteArgs(
        mode: q['mode'],
        preset: q['preset'],
        focus: q['focus'],
        hops: q['hops'],
        lens: q['lens'],
        a: q['a'],
        b: q['b'],
      );

  final String? mode;
  final String? preset;
  final String? focus;
  final String? hops;
  final String? lens;
  final String? a;
  final String? b;

  bool get isEmpty =>
      [mode, preset, focus, hops, lens, a, b].every((v) => v == null);

  /// Applies the recognised parameters to [s]; anything unrecognised is
  /// ignored.
  ConnectionsViewState apply(ConnectionsViewState s) {
    var next = s;
    final preset = ConnectionPresets.byId(this.preset ?? lens);
    final kindA = ConnectionKind.fromName(a);
    final kindB = ConnectionKind.fromName(b);
    if (preset != null) {
      next = next.applyPreset(preset);
    } else if (kindA != null && kindB != null) {
      next = next.showMap(MapSpec.of({kindA, kindB}, {KindLink(kindA, kindB)}));
    }
    final ref = NodeRef.parse(focus);
    if (ref != null && mode != 'map') next = next.centreOn(ref);
    next = next.withHopsParam(hops);
    if (mode == 'map') next = next.withMode(ConnectionsMode.map);
    if (mode == 'around' && ref == null) {
      next = next.withMode(ConnectionsMode.around);
    }
    return next;
  }
}
