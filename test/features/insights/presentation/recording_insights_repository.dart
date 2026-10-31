import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
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

  /// What [getWaterTempBandPerDive] answers.
  Map<String, int> bandPerDive = const {};

  @override
  Future<Map<String, int>> getWaterTempBandPerDive({
    required TemperatureUnit unit,
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async => bandPerDive;

  /// The last chart query and its key, such as `gasMix:Nitrox`.
  String? lastAsked;

  Future<List<String>> _ask(String asked) async {
    lastAsked = asked;
    return ids;
  }

  @override
  Future<List<String>> getVisibilityDiveIds({
    required VisibilityScale scale,
    required String bucket,
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _ask('visibility:$bucket');

  @override
  Future<List<String>> getSiteTypeDiveIds({
    required String siteTypeId,
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _ask('siteType:$siteTypeId');

  @override
  Future<List<String>> getGasMixDiveIds({
    required String gasType,
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _ask('gasMix:$gasType');

  @override
  Future<List<String>> getSuitThicknessDiveIds({
    required String bucket,
    double? mm,
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _ask('suit:$bucket:$mm');

  @override
  Future<List<String>> getDepthBucketDiveIds({
    required int bucket,
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _ask('depth:$bucket');

  @override
  Future<({List<String> solo, List<String> buddy, List<String> notRecorded})>
  getSoloVsBuddyDiveIds({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async => (
    solo: const ['solo-dive'],
    buddy: const ['buddy-dive'],
    notRecorded: const ['unrecorded-dive'],
  );
}
