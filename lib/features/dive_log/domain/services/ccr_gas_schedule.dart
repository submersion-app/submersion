import 'package:equatable/equatable.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

/// What a recorded gas switch means on a closed-circuit dive (issue #577).
enum CcrGasChangeKind {
  /// The diver is on the loop, breathing over this diluent.
  diluent,

  /// The diver has bailed out and breathes this cylinder open circuit.
  openCircuit,
}

/// A change of breathing gas on a CCR dive, derived from a gas switch and
/// the role of the cylinder switched to.
class CcrGasChange extends Equatable {
  const CcrGasChange({
    required this.timestamp,
    required this.kind,
    required this.fN2,
    this.fHe = 0.0,
  });

  /// Seconds from dive start.
  final int timestamp;
  final CcrGasChangeKind kind;

  /// Nitrogen fraction (0.0-1.0) of the diluent or open-circuit gas.
  final double fN2;

  /// Helium fraction (0.0-1.0) of the diluent or open-circuit gas.
  final double fHe;

  @override
  List<Object?> get props => [timestamp, kind, fN2, fHe];
}

/// Classifies a CCR dive's gas switches by the role of the cylinder switched
/// to. A diluent switch puts the diver on the loop over that diluent (ending a
/// bailout); a switch to any open-circuit cylinder is a bailout onto it. The
/// O2 supply feeds the loop, so a switch to it while on the loop is dropped;
/// once bailed out it is open circuit on O2.
///
/// [tanks] is the cylinder set the analysed computer breathed: a switch to a
/// cylinder outside it is dropped. The result is ordered by timestamp, ties
/// broken by switch id as the open-circuit schedule does.
List<CcrGasChange> classifyCcrGasChanges(
  List<GasSwitchWithTank> switches,
  List<DiveTank> tanks,
) {
  final roles = {for (final tank in tanks) tank.id: tank.role};
  final ordered =
      switches.where((s) => roles.containsKey(s.gasSwitch.tankId)).toList()
        ..sort((a, b) {
          final byTime = a.gasSwitch.timestamp.compareTo(b.gasSwitch.timestamp);
          return byTime != 0
              ? byTime
              : a.gasSwitch.id.compareTo(b.gasSwitch.id);
        });

  var onLoop = true;
  final changes = <CcrGasChange>[];
  for (final gasSwitch in ordered) {
    final kind = switch (roles[gasSwitch.gasSwitch.tankId]!) {
      TankRole.diluent => CcrGasChangeKind.diluent,
      TankRole.oxygenSupply => onLoop ? null : CcrGasChangeKind.openCircuit,
      _ => CcrGasChangeKind.openCircuit,
    };
    if (kind == null) continue;
    onLoop = kind == CcrGasChangeKind.diluent;
    changes.add(
      CcrGasChange(
        timestamp: gasSwitch.gasSwitch.timestamp,
        kind: kind,
        fN2: gasSwitch.isAir ? airN2Fraction : gasSwitch.n2Fraction,
        fHe: gasSwitch.heFraction,
      ),
    );
  }
  return changes;
}
