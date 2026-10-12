import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// What a pushed dive list puts back when it goes away: the dive-list filter
/// and highlighted dive that were in place before it opened.
///
/// Carried as the `/dives` route's `extra`. The highlight matters as much as
/// the filter: it is global, and a table-mode list under the pushed one
/// replays it into its own URL once uncovered (#3292).
class DiveListReturn {
  const DiveListReturn({required this.filter, required this.highlightedDiveId});

  final DiveFilterState filter;
  final String? highlightedDiveId;
}
