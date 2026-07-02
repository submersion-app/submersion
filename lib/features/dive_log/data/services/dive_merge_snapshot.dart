import 'package:submersion/core/database/database.dart';

/// Plain-data capture of every row touched by a dive merge (#449), taken
/// before mutation so a merge can later be undone.
///
/// `Dive`, `DiveTank`, `DiveWeight`, `Sighting`, `DiveCustomField` here are
/// the Drift row classes (from database.dart), not the domain entities of
/// the same name.
class DiveMergeSnapshot {
  const DiveMergeSnapshot({
    required this.mergedDiveId,
    required this.diveRows,
    required this.profileRows,
    required this.tankRows,
    required this.weightRows,
    required this.customFieldRows,
    required this.equipmentRows,
    required this.diveTypeRows,
    required this.tagRows,
    required this.buddyRows,
    required this.sightingRows,
    required this.eventRows,
    required this.gasSwitchRows,
    required this.tankPressureRows,
    required this.dataSourceRows,
    required this.tideRows,
    required this.mediaDiveIds,
  });

  /// The id assigned to the new merged dive.
  final String mergedDiveId;

  final List<Dive> diveRows;
  final List<DiveProfile> profileRows;
  final List<DiveTank> tankRows;
  final List<DiveWeight> weightRows;
  final List<DiveCustomField> customFieldRows;
  final List<DiveEquipmentData> equipmentRows;
  final List<DiveDiveType> diveTypeRows;
  final List<DiveTag> tagRows;
  final List<DiveBuddy> buddyRows;
  final List<Sighting> sightingRows;
  final List<DiveProfileEvent> eventRows;
  final List<GasSwitche> gasSwitchRows;
  final List<TankPressureProfile> tankPressureRows;
  final List<DiveDataSourcesData> dataSourceRows;
  final List<TideRecord> tideRows;

  /// Media id -> original dive id, so an undo can point media back at its
  /// source dive.
  final Map<String, String> mediaDiveIds;
}
