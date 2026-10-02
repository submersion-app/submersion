import 'package:equatable/equatable.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';

class ConnectionPreset extends Equatable {
  const ConnectionPreset({required this.id, required this.spec});

  final String id;
  final MapSpec spec;

  @override
  List<Object?> get props => [id, spec];
}

/// The nine built-in maps, in display order (spec Revision 2, Presets).
class ConnectionPresets {
  const ConnectionPresets._();

  static const _b = ConnectionKind.buddy;
  static const _s = ConnectionKind.site;
  static const _t = ConnectionKind.trip;
  static const _c = ConnectionKind.diveCenter;
  static const _e = ConnectionKind.equipment;
  static const _sp = ConnectionKind.species;
  static const _dt = ConnectionKind.diveType;

  static ConnectionPreset _p(
    String id,
    Set<ConnectionKind> kinds,
    List<KindLink> links,
  ) => ConnectionPreset(id: id, spec: MapSpec.of(kinds, links.toSet()));

  static final List<ConnectionPreset> all = List.unmodifiable([
    _p('circle', {_b}, [KindLink(_b, _b)]),
    _p('where', {_b, _s}, [KindLink(_b, _s)]),
    _p('trips', {_b, _t}, [KindLink(_b, _t)]),
    _p('life', {_s, _sp}, [KindLink(_s, _sp)]),
    _p('gear', {_e}, [KindLink(_e, _e)]),
    _p('centers', {_c, _b}, [KindLink(_c, _b)]),
    _p(
      'travel',
      {_b, _t, _s},
      [KindLink(_b, _t), KindLink(_t, _s), KindLink(_b, _s)],
    ),
    _p(
      'reef',
      {_s, _sp, _dt},
      [KindLink(_s, _sp), KindLink(_sp, _dt), KindLink(_s, _dt)],
    ),
    _p(
      'gearRoad',
      {_e, _t, _c},
      [KindLink(_e, _t), KindLink(_t, _c), KindLink(_e, _c)],
    ),
  ]);

  static ConnectionPreset? byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
