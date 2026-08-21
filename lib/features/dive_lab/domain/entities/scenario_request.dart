import 'package:equatable/equatable.dart';

/// A recorded gas switch on the primary profile: from [timestamp] the diver
/// breathed [tankId].
class ScenarioGasSwitch extends Equatable {
  const ScenarioGasSwitch({required this.timestamp, required this.tankId});
  final int timestamp;
  final String tankId;
  @override
  List<Object?> get props => [timestamp, tankId];
}

/// One point of a tank's recorded pressure series.
class TankPressureSample extends Equatable {
  const TankPressureSample({
    required this.timestamp,
    required this.pressureBar,
  });
  final int timestamp;
  final double pressureBar;
  @override
  List<Object?> get props => [timestamp, pressureBar];
}
