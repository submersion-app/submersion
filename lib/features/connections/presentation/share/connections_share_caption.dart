import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_caption_text.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The two caption lines under a shared map image: what the map is, then
/// when and how much.
class ConnectionsShareCaption {
  const ConnectionsShareCaption({required this.title, required this.details});

  final String title;
  final String details;

  /// [title] names the centre in Around mode, else the saved map, the
  /// preset, or "Custom map". [details] gives the filter's date range (or
  /// the log's year span) and the node and connection counts.
  static ConnectionsShareCaption of({
    required AppLocalizations l10n,
    required UnitFormatter units,
    required ConnectionsViewState view,
    required ConnectionGraph graph,
    required DiveFilterState filter,
    required ({int first, int last})? span,
    required Map<String, String> savedMapNames,
  }) {
    final title = connectionsMapTitle(
      l10n: l10n,
      view: view,
      graph: graph,
      savedMapNames: savedMapNames,
    );
    final String range;
    if (filter.startDate != null || filter.endDate != null) {
      range = units.formatDateRange(
        filter.startDate,
        filter.endDate,
        l10n: l10n,
      );
    } else if (span != null) {
      range = l10n.connections_share_allDives(span.first, span.last);
    } else {
      range = '';
    }
    final counts = l10n.connections_semantics_summary(
      graph.nodes.length,
      graph.edges.length,
    );
    return ConnectionsShareCaption(
      title: title,
      details: range.isEmpty
          ? counts
          : l10n.connections_share_details(range, counts),
    );
  }
}
