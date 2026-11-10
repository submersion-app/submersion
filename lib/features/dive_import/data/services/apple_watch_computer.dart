import 'package:uuid/uuid.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

/// The "Apple Watch" computer of [diverId] (issue #637), made the first time
/// it is needed. Dives from Apple Health are attributed to it, so a merge
/// with a dive computer download can tell the two sets of readings apart,
/// and it shows in the Dive Computers list like any other.
Future<DiveComputer> appleWatchComputerFor(
  DiveComputerRepository computers,
  String diverId,
) async {
  final computer = await computers.findOrRegisterImportedComputer(
    model: DiveComputer.appleWatchModel,
    manufacturer: DiveComputer.appleWatchManufacturer,
    diverId: diverId,
  );
  // A non-empty model always finds or makes a row.
  return computer!;
}

/// The id a dive imported from the Apple Health workout [workoutUuid] takes
/// for [diverId]: the same on every device, so an iPhone and an iPad that
/// both import a workout converge on one dive through sync.
String healthDiveId({required String diverId, required String workoutUuid}) =>
    const Uuid().v5(
      Namespace.url.value,
      'submersion:applehealth:$diverId:$workoutUuid',
    );
