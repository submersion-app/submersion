import 'package:equatable/equatable.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';

enum ConnectionsMode { around, map }

const Set<ConnectionKind> kDefaultAroundKinds = {
  ConnectionKind.buddy,
  ConnectionKind.site,
  ConnectionKind.trip,
  ConnectionKind.species,
  ConnectionKind.equipment,
  ConnectionKind.diveCenter,
};

/// Everything the Connections page shows, in one immutable value. Both
/// modes' settings live here at once, so switching modes restores each side.
class ConnectionsViewState extends Equatable {
  const ConnectionsViewState({
    required this.mode,
    required this.mapSpec,
    this.presetId,
    this.editedFromPresetId,
    this.savedMapId,
    this.focus,
    this.aroundKinds = kDefaultAroundKinds,
    this.hops = 1,
  });

  static final ConnectionsViewState initial = ConnectionsViewState(
    mode: ConnectionsMode.map,
    mapSpec: ConnectionPresets.byId('circle')!.spec,
    presetId: 'circle',
  );

  final ConnectionsMode mode;
  final MapSpec mapSpec;

  /// The preset card currently applied unedited, or null.
  final String? presetId;

  /// The preset the current custom map was edited from; its card shows an
  /// "edited" mark until another card is chosen.
  final String? editedFromPresetId;

  /// The saved map currently applied, or null.
  final String? savedMapId;

  final NodeRef? focus;
  final Set<ConnectionKind> aroundKinds;
  final int hops;

  bool get isAroundWithoutFocus =>
      mode == ConnectionsMode.around && focus == null;

  ConnectionsViewState applyPreset(ConnectionPreset preset) =>
      ConnectionsViewState(
        mode: ConnectionsMode.map,
        mapSpec: preset.spec,
        presetId: preset.id,
        focus: focus,
        aroundKinds: aroundKinds,
        hops: hops,
      );

  ConnectionsViewState applySavedMap(String id, MapSpec spec) =>
      ConnectionsViewState(
        mode: ConnectionsMode.map,
        mapSpec: spec,
        savedMapId: id,
        focus: focus,
        aroundKinds: aroundKinds,
        hops: hops,
      );

  /// Shows [spec] as a custom map without marking any preset edited (a map
  /// that arrives from outside, such as a phase 1 pair link).
  ConnectionsViewState showMap(MapSpec spec) => ConnectionsViewState(
    mode: ConnectionsMode.map,
    mapSpec: spec,
    focus: focus,
    aroundKinds: aroundKinds,
    hops: hops,
  );

  /// Reconciles the applied saved map with the current saved maps: follows
  /// an edit made elsewhere, and turns the view custom when the map is gone
  /// (what is on screen stays). Returns this view unchanged otherwise.
  ConnectionsViewState withSavedMaps(Map<String, MapSpec> savedById) {
    final id = savedMapId;
    if (id == null) return this;
    final spec = savedById[id];
    if (spec == null) return showMap(mapSpec).withMode(mode);
    if (spec == mapSpec) return this;
    return ConnectionsViewState(
      mode: mode,
      mapSpec: spec,
      savedMapId: id,
      focus: focus,
      aroundKinds: aroundKinds,
      hops: hops,
    );
  }

  /// Any edit to the map makes it a custom map.
  ConnectionsViewState editMap(MapSpec spec) => ConnectionsViewState(
    mode: ConnectionsMode.map,
    mapSpec: spec,
    editedFromPresetId: presetId ?? editedFromPresetId,
    focus: focus,
    aroundKinds: aroundKinds,
    hops: hops,
  );

  ConnectionsViewState centreOn(NodeRef ref) =>
      copyWith(mode: ConnectionsMode.around, focus: ref);

  ConnectionsViewState withMode(ConnectionsMode m) => copyWith(mode: m);

  ConnectionsViewState withAroundKinds(Set<ConnectionKind> kinds) =>
      copyWith(aroundKinds: Set.unmodifiable(kinds));

  ConnectionsViewState withHops(int n) => copyWith(hops: n.clamp(1, 3));

  /// Applies a `hops` route parameter; a missing or unreadable one leaves
  /// the view as it is (a deep link never fails on a malformed value).
  ConnectionsViewState withHopsParam(String? raw) {
    final n = raw == null ? null : int.tryParse(raw);
    return n == null ? this : withHops(n);
  }

  ConnectionsViewState copyWith({
    ConnectionsMode? mode,
    MapSpec? mapSpec,
    NodeRef? focus,
    bool clearFocus = false,
    Set<ConnectionKind>? aroundKinds,
    int? hops,
  }) {
    return ConnectionsViewState(
      mode: mode ?? this.mode,
      mapSpec: mapSpec ?? this.mapSpec,
      presetId: presetId,
      editedFromPresetId: editedFromPresetId,
      savedMapId: savedMapId,
      focus: clearFocus ? null : (focus ?? this.focus),
      aroundKinds: aroundKinds ?? this.aroundKinds,
      hops: hops ?? this.hops,
    );
  }

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'map': mapSpec.toJson(),
    'preset': presetId,
    'editedFrom': editedFromPresetId,
    'saved': savedMapId,
    'focus': focus?.wire,
    'aroundKinds': [
      for (final k
          in (aroundKinds.toList()..sort((a, b) => a.index.compareTo(b.index))))
        k.name,
    ],
    'hops': hops,
  };

  static ConnectionsViewState? fromJson(Object? json) {
    if (json is! Map) return null;
    final mode = ConnectionsMode.values
        .where((m) => m.name == json['mode'])
        .firstOrNull;
    final spec = MapSpec.fromJson(json['map']);
    if (mode == null || spec == null) return null;
    final rawKinds = json['aroundKinds'];
    final kinds = <ConnectionKind>{};
    if (rawKinds is List) {
      for (final r in rawKinds) {
        final k = r is String ? ConnectionKind.fromName(r) : null;
        if (k != null) kinds.add(k);
      }
    }
    final hops = json['hops'];
    return ConnectionsViewState(
      mode: mode,
      mapSpec: spec,
      presetId: json['preset'] is String ? json['preset'] as String : null,
      editedFromPresetId: json['editedFrom'] is String
          ? json['editedFrom'] as String
          : null,
      savedMapId: json['saved'] is String ? json['saved'] as String : null,
      focus: NodeRef.parse(
        json['focus'] is String ? json['focus'] as String : null,
      ),
      // A stored empty list is the diver's choice; only a view stored
      // before the field existed falls back to the defaults.
      aroundKinds: rawKinds is List
          ? Set.unmodifiable(kinds)
          : kDefaultAroundKinds,
      hops: hops is int ? hops.clamp(1, 3) : 1,
    );
  }

  /// Phase 1 stored a lens id or `custom:<a>:<b>` under
  /// `connections_last_lens`; this turns either into a view.
  static ConnectionsViewState fromLegacyLens(String? value) {
    final preset = ConnectionPresets.byId(value);
    if (preset != null) return initial.applyPreset(preset);
    final parts = value?.split(':');
    if (parts != null && parts.length == 3 && parts[0] == 'custom') {
      final a = ConnectionKind.fromName(parts[1]);
      final b = ConnectionKind.fromName(parts[2]);
      if (a != null && b != null) {
        // Not editMap: a legacy pair must not mark Dive circle as edited.
        return initial.showMap(MapSpec.of({a, b}, {KindLink(a, b)}));
      }
    }
    return initial;
  }

  @override
  List<Object?> get props => [
    mode,
    mapSpec,
    presetId,
    editedFromPresetId,
    savedMapId,
    focus,
    aroundKinds,
    hops,
  ];
}
