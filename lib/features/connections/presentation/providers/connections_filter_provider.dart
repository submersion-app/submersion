import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// The Connections page's own view filter.
///
/// Deliberately separate from `diveFilterProvider` (the dive list) and
/// `insightsFilterProvider`: scoping the graph must never scope the list
/// or the charts, and vice versa.
final connectionsFilterProvider = StateProvider<DiveFilterState>(
  (ref) => const DiveFilterState(),
);
