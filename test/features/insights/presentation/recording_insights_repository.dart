import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

/// Stands in for the database behind a chart's link (#3805): answers with
/// [ids] and keeps what it was asked for.
class RecordingInsightsRepository extends InsightsRepository {
  RecordingInsightsRepository({this.ids = const ['d1']});

  final List<String> ids;
  DiveFilterState? lastFilter;
  bool? lastGas;

  @override
  Future<List<String>> getCountedDiveIds({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    bool gas = false,
  }) async {
    lastFilter = filter;
    lastGas = gas;
    return ids;
  }
}
