import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/panel/preset_grid.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The name of the map in view: the centre in Around mode, else the saved
/// map, the preset, or "Custom map". The canvas caption and the share image
/// both use it.
String connectionsMapTitle({
  required AppLocalizations l10n,
  required ConnectionsViewState view,
  required ConnectionGraph graph,
  required Map<String, String> savedMapNames,
}) {
  final focus = view.focus;
  if (view.mode == ConnectionsMode.around && focus != null) {
    return l10n.connections_share_aroundName(
      graph.nodeFor(focus)?.label ?? focus.id,
    );
  }
  final presetId = view.presetId;
  return savedMapNames[view.savedMapId] ??
      (presetId != null
          ? presetLabel(l10n, presetId)
          : l10n.connections_editor_title);
}

/// What the canvas caption says: which map this is, and how to read it.
class ConnectionsCaptionText {
  const ConnectionsCaptionText({required this.title, required this.sentence});

  final String title;
  final String sentence;

  /// The sentence reads a line for the preset or mode in view, and adds
  /// that thicker lines mean more dives unless every line is drawn thin.
  static ConnectionsCaptionText of({
    required AppLocalizations l10n,
    required ConnectionsViewState view,
    required ConnectionGraph graph,
    required EdgeMode edges,
    required Map<String, String> savedMapNames,
  }) {
    final base = view.mode == ConnectionsMode.around
        ? l10n.connections_caption_around(view.hops)
        : _presetSentence(l10n, view);
    return ConnectionsCaptionText(
      title: connectionsMapTitle(
        l10n: l10n,
        view: view,
        graph: graph,
        savedMapNames: savedMapNames,
      ),
      sentence: edges == EdgeMode.thin
          ? base
          : '$base ${l10n.connections_caption_thicker}',
    );
  }

  static String _presetSentence(
    AppLocalizations l10n,
    ConnectionsViewState view,
  ) => switch (view.presetId) {
    'circle' => l10n.connections_caption_circle,
    'where' => l10n.connections_caption_where,
    'trips' => l10n.connections_caption_trips,
    'life' => l10n.connections_caption_life,
    'gear' => l10n.connections_caption_gear,
    'centers' => l10n.connections_caption_centers,
    'travel' => l10n.connections_caption_travel,
    'reef' => l10n.connections_caption_reef,
    'gearRoad' => l10n.connections_caption_gearRoad,
    _ => l10n.connections_caption_custom(_kindList(l10n, view)),
  };

  /// The map's kinds by name, in kind order: the legend is in the panel on
  /// a wide screen, so a custom map's sentence names them itself.
  static String _kindList(AppLocalizations l10n, ConnectionsViewState view) {
    final kinds = view.mapSpec.kinds.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return kinds
        .map((k) => kindLabel(l10n, k))
        .join(l10n.connections_caption_kindSeparator);
  }
}
