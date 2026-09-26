import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// Independent filter for the Insights tab. Deliberately NOT the same as
/// diveFilterProvider (the dive list) so filtering stats never rescopes the
/// list, the home dashboard, or vice-versa.
final insightsFilterProvider = StateProvider<DiveFilterState>(
  (ref) => const DiveFilterState(),
);
