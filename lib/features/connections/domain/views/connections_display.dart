import 'package:equatable/equatable.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';

/// Which presentation of the map the page shows.
enum ConnectionsViewKind { graph, pairs, entities, matrix }

/// Which node labels the graph draws.
enum LabelMode { auto, all, off }

/// How big each node disc is.
enum NodeSizeMode { byDives, uniform }

/// How the graph draws its edges.
enum EdgeMode { weighted, thin, selectedOnly }

T _named<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return fallback;
}

/// How the Connections page presents a map: which view, which layout per
/// mode, and how the graph is drawn. Remembered on this device only and
/// kept apart from the view state, which says what is shown.
class ConnectionsDisplay extends Equatable {
  const ConnectionsDisplay({
    this.view = ConnectionsViewKind.graph,
    this.mapLayout = ConnectionsLayout.web,
    this.aroundLayout = ConnectionsLayout.radial,
    this.labels = LabelMode.auto,
    this.nodeSize = NodeSizeMode.byDives,
    this.edges = EdgeMode.weighted,
    this.hideUnconnected = false,
    this.spacing = 1.0,
  });

  static const initial = ConnectionsDisplay();
  static const double minSpacing = 0.6;
  static const double maxSpacing = 2.0;

  final ConnectionsViewKind view;
  final ConnectionsLayout mapLayout;
  final ConnectionsLayout aroundLayout;
  final LabelMode labels;
  final NodeSizeMode nodeSize;
  final EdgeMode edges;
  final bool hideUnconnected;

  /// Multiplies every layout's distances; [minSpacing] to [maxSpacing].
  final double spacing;

  ConnectionsLayout layoutFor({required bool around}) =>
      around ? aroundLayout : mapLayout;

  /// Sets [layout] for one mode. A layout that mode does not offer leaves
  /// the display as it is.
  ConnectionsDisplay withLayout(
    ConnectionsLayout layout, {
    required bool around,
  }) {
    final offered = around
        ? ConnectionsLayout.forAround
        : ConnectionsLayout.forMap;
    if (!offered.contains(layout)) return this;
    return around
        ? copyWith(aroundLayout: layout)
        : copyWith(mapLayout: layout);
  }

  ConnectionsDisplay copyWith({
    ConnectionsViewKind? view,
    ConnectionsLayout? mapLayout,
    ConnectionsLayout? aroundLayout,
    LabelMode? labels,
    NodeSizeMode? nodeSize,
    EdgeMode? edges,
    bool? hideUnconnected,
    double? spacing,
  }) {
    return ConnectionsDisplay(
      view: view ?? this.view,
      mapLayout: mapLayout ?? this.mapLayout,
      aroundLayout: aroundLayout ?? this.aroundLayout,
      labels: labels ?? this.labels,
      nodeSize: nodeSize ?? this.nodeSize,
      edges: edges ?? this.edges,
      hideUnconnected: hideUnconnected ?? this.hideUnconnected,
      spacing: (spacing ?? this.spacing)
          .clamp(minSpacing, maxSpacing)
          .toDouble(),
    );
  }

  Map<String, Object?> toJson() => {
    'view': view.name,
    'mapLayout': mapLayout.name,
    'aroundLayout': aroundLayout.name,
    'labels': labels.name,
    'nodeSize': nodeSize.name,
    'edges': edges.name,
    'hideUnconnected': hideUnconnected,
    'spacing': spacing,
  };

  /// Reads a stored display. Each field falls back to its default on its
  /// own, so one unreadable value never resets the rest.
  static ConnectionsDisplay fromJson(Object? json) {
    if (json is! Map) return initial;
    final mapLayout = ConnectionsLayout.fromName(
      json['mapLayout'] is String ? json['mapLayout'] as String : null,
    );
    final aroundLayout = ConnectionsLayout.fromName(
      json['aroundLayout'] is String ? json['aroundLayout'] as String : null,
    );
    final hide = json['hideUnconnected'];
    final spacing = json['spacing'];
    return ConnectionsDisplay(
      view: _named(ConnectionsViewKind.values, json['view'], initial.view),
      mapLayout:
          mapLayout != null && ConnectionsLayout.forMap.contains(mapLayout)
          ? mapLayout
          : initial.mapLayout,
      aroundLayout:
          aroundLayout != null &&
              ConnectionsLayout.forAround.contains(aroundLayout)
          ? aroundLayout
          : initial.aroundLayout,
      labels: _named(LabelMode.values, json['labels'], initial.labels),
      nodeSize: _named(NodeSizeMode.values, json['nodeSize'], initial.nodeSize),
      edges: _named(EdgeMode.values, json['edges'], initial.edges),
      hideUnconnected: hide is bool ? hide : initial.hideUnconnected,
      spacing: spacing is num && spacing.isFinite
          ? spacing.toDouble().clamp(minSpacing, maxSpacing).toDouble()
          : initial.spacing,
    );
  }

  @override
  List<Object?> get props => [
    view,
    mapLayout,
    aroundLayout,
    labels,
    nodeSize,
    edges,
    hideUnconnected,
    spacing,
  ];
}
