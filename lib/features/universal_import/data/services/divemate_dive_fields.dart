import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/services/divemate_values.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

/// Adds what only a DiveMate file carries to the dive and cylinder maps
/// `DivingLogDiveMapper` builds (#3110).
///
/// Kept out of that mapper so a Diving Log file never reaches this code and
/// the mapper does not grow a branch per DiveMate column. Every key written
/// here is one `UddfEntityImporter` reads.
abstract final class DiveMateDiveFields {
  /// Writes [raw]'s conditions into [dive]. A value DiveMate stored but no
  /// field can hold (visibility or current text that names no level) is
  /// kept in the notes rather than dropped.
  static void applyToDive(
    Map<String, dynamic> dive,
    DivingLogRawDive raw,
    DivingLogLogbook book,
  ) {
    final extras = raw.diveMate;
    if (extras == null) return;

    // The dive's own water, else the water of the site it was at.
    final place = raw.placeId == null ? null : book.placesById[raw.placeId];
    final water =
        DiveMateValues.waterType(extras.water) ??
        DiveMateValues.waterType(place?.water);
    if (water != null) dive['waterType'] = water.name;

    final rating = DiveMateValues.rating(extras.rating);
    if (rating != null) dive['rating'] = rating;

    final leftover = <String>[];
    final visibility = DiveMateValues.visibility(extras.visibility);
    if (visibility.level != null) {
      dive['visibility'] = visibility.level!.name;
    } else if (visibility.meters != null) {
      dive['visibilityMeters'] = visibility.meters;
    } else if (visibility.text != null) {
      leftover.add('Visibility: ${visibility.text}');
    }

    final current = DiveMateValues.current(extras.current);
    if (current != null) {
      dive['currentStrength'] = current.name;
    } else if (extras.current != null) {
      leftover.add('Current: ${extras.current}');
    }

    if (extras.waves != null) dive['surfaceConditions'] = extras.waves;
    if (extras.weather != null) dive['weatherDescription'] = extras.weather;

    final entry = DiveMateValues.entryMethod(extras.entry);
    if (entry != null) dive['entryMethod'] = entry.name;
    if (extras.boat != null) dive['boatName'] = extras.boat;

    final interval = DiveMateValues.surfaceInterval(extras.surfaceInterval);
    if (interval != null) dive['surfaceInterval'] = interval;

    if (leftover.isNotEmpty) {
      dive['notes'] = [
        if (dive['notes'] case final String notes when notes.isNotEmpty) notes,
        leftover.join('\n'),
      ].join('\n\n');
    }
  }

  /// Writes each cylinder's name, material, role and breathing time into
  /// [tanks], which `DivingLogDiveMapper` built from [raws] in the same
  /// order.
  static void applyToTanks(
    List<Map<String, dynamic>> tanks,
    List<DivingLogRawTank> raws,
  ) {
    var sidemount = 0;
    for (var i = 0; i < tanks.length && i < raws.length; i++) {
      final extras = raws[i].diveMate;
      if (extras == null) continue;
      final tank = tanks[i];
      if (extras.name != null) tank['name'] = extras.name;
      final material = DiveMateValues.tankMaterial(extras.material);
      if (material != null) tank['material'] = material.name;
      final role = DiveMateValues.tankRole(
        divePhase: extras.divePhase,
        supplyType: extras.supplyType,
        sidemountIndex: sidemount,
      );
      if (role == TankRole.sidemountLeft || role == TankRole.sidemountRight) {
        sidemount++;
      }
      tank['role'] = role.name;
      final seconds = extras.breathingSeconds;
      if (seconds != null && seconds > 0) {
        tank['usageDuration'] = Duration(seconds: seconds);
      }
    }
  }
}
