import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';

/// The deep link every detail page's "Open in Connections" pushes.
String connectionsAroundLocation(NodeRef ref) =>
    '/connections?mode=around&focus=${ref.wire}';

/// `/connections` query parameters. Revision 2 uses `mode`, `preset`,
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
    final n = int.tryParse(hops ?? '');
    if (n != null) next = next.withHops(n);
    if (mode == 'map') next = next.withMode(ConnectionsMode.map);
    if (mode == 'around' && ref == null) {
      next = next.withMode(ConnectionsMode.around);
    }
    return next;
  }
}
