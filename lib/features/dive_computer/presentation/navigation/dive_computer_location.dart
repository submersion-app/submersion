import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

/// Where tapping [computer] goes: its Equipment item, which is its one entry
/// (issue #3676). The computer route is the fallback for a registration the
/// device gear heal has not given an item yet; it forwards once it has one.
String diveComputerLocation(DiveComputer computer) {
  final item = computer.equipmentId;
  return item == null ? '/dive-computers/${computer.id}' : '/equipment/$item';
}
