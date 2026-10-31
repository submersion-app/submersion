import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// [diveData]'s gas switches as rows of the imported dive, each under the
/// computer that logged it. A switch with no time, or naming no tank of
/// [tanks], is dropped.
///
/// [computerIdByOrdinal] is the dive's restored computers by `<source>`
/// ordinal: a switch naming no ordinal in it stays unattributed, as every
/// switch of a file without `<source>` entries does (issue #3966).
List<GasSwitch> importedGasSwitches(
  Map<String, dynamic> diveData, {
  required String diveId,
  required List<DiveTank> tanks,
  required Map<int, String?> computerIdByOrdinal,
  required DateTime now,
}) {
  final gasSwitchesData =
      diveData['gasSwitches'] as List<Map<String, dynamic>>?;
  if (gasSwitchesData == null || gasSwitchesData.isEmpty) return const [];

  // Build lookups from both UDDF tank ID and UDDF gas mix UUID to the
  // persisted tank row id. MacDive-style switches reference a gas mix
  // UUID (via <switchmix ref>), while top-level <gasswitches>
  // entries reference a tank UUID (via <tankref>); we accept either.
  // FIT imports carry no refs at all and address tanks positionally
  // via `tankIndex`.
  final tankIdByRef = <String, String>{};
  final tankIdByGasMixRef = <String, String>{};
  final tanksData = diveData['tanks'] as List<Map<String, dynamic>>?;
  if (tanksData != null) {
    for (var i = 0; i < tanks.length && i < tanksData.length; i++) {
      final tank = tanks[i];
      final tankData = tanksData[i];
      final ref = (tankData['uddfTankId'] as String?)?.trim();
      if (ref != null && ref.isNotEmpty) {
        tankIdByRef[ref] = tank.id;
      }
      final gasMixRef = (tankData['uddfGasMixRef'] as String?)?.trim();
      // First tank linked to a given gas wins; later tanks sharing the
      // same gas don't overwrite. This is a pragmatic resolution for
      // dives where multiple tanks carry the same mix.
      if (gasMixRef != null &&
          gasMixRef.isNotEmpty &&
          !tankIdByGasMixRef.containsKey(gasMixRef)) {
        tankIdByGasMixRef[gasMixRef] = tank.id;
      }
    }
  }

  return gasSwitchesData
      .map((gs) {
        final timestamp = gs['timestamp'] as int?;
        if (timestamp == null) return null;
        final tankRef = (gs['tankRef'] as String?)?.trim();
        final gasMixRef = (gs['gasMixRef'] as String?)?.trim();
        String? tankId;
        if (tankRef != null && tankRef.isNotEmpty) {
          tankId = tankIdByRef[tankRef];
        }
        if ((tankId == null || tankId.isEmpty) &&
            gasMixRef != null &&
            gasMixRef.isNotEmpty) {
          tankId = tankIdByGasMixRef[gasMixRef];
        }
        if (tankId == null || tankId.isEmpty) {
          final tankIndex = gs['tankIndex'] as int?;
          if (tankIndex != null && tankIndex >= 0 && tankIndex < tanks.length) {
            tankId = tanks[tankIndex].id;
          }
        }
        if (tankId == null || tankId.isEmpty) return null;
        return GasSwitch(
          id: _uuid.v4(),
          diveId: diveId,
          timestamp: timestamp,
          tankId: tankId,
          depth: gs['depth'] as double?,
          createdAt: now,
          computerId: computerIdByOrdinal[gs['computerOrdinal']],
        );
      })
      .whereType<GasSwitch>()
      .toList();
}
