import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';

/// Gas switches as breathing gas calculations read them (issue #4243).
///
/// A suit inflation bottle is not breathing gas, yet a downloaded computer
/// can attach a switch to it when its gas list holds the bottle's mix, which
/// is air in practice, the same as the back gas. Dropping that switch would
/// leave the diver on the previous gas (a deco mix, say) and understate deco,
/// the unsafe direction. So a switch to a suit bottle moves to the breathing
/// cylinder on the same mix, the SAC reference cylinder first when it
/// matches, and is dropped only when no breathing cylinder holds that mix.
/// The stored switch is never rewritten: this is how calculations read it.
///
/// A switch to a breathing cylinder, or to a cylinder not in the list, is
/// kept as it is.
List<GasSwitch> breathingRawGasSwitches(
  List<GasSwitch> switches,
  List<DiveTank> tanks,
) {
  final targets = _Targets(tanks);
  if (!targets.hasSuit) return switches;
  return [
    for (final sw in switches)
      if (targets.resolve(sw.tankId) case final tankId?)
        tankId == sw.tankId ? sw : sw.copyWith(tankId: tankId),
  ];
}

/// [breathingRawGasSwitches] for switches that carry their cylinder's name
/// and mix: a moved switch takes the new cylinder's.
List<GasSwitchWithTank> breathingGasSwitches(
  List<GasSwitchWithTank> switches,
  List<DiveTank> tanks,
) {
  final targets = _Targets(tanks);
  if (!targets.hasSuit) return switches;
  final byId = {for (final tank in tanks) tank.id: tank};
  return [
    for (final sw in switches)
      if (targets.resolve(sw.gasSwitch.tankId) case final tankId?)
        tankId == sw.gasSwitch.tankId ? sw : _relabel(sw, byId[tankId]!),
  ];
}

/// The rule [breathingRawGasSwitches] applies, for a switch type of its own
/// (the Dive Lab's): the cylinder a switch to a tank id counts against, the
/// id itself for a breathing or unknown tank, null to drop it.
String? Function(String tankId) breathingSwitchTarget(List<DiveTank> tanks) =>
    _Targets(tanks).resolve;

GasSwitchWithTank _relabel(GasSwitchWithTank sw, DiveTank tank) =>
    GasSwitchWithTank(
      gasSwitch: sw.gasSwitch.copyWith(tankId: tank.id),
      tankName: tank.name ?? '',
      gasMix: tank.gasMix.name,
      o2Fraction: tank.gasMix.o2 / 100,
      heFraction: tank.gasMix.he / 100,
    );

/// Where a switch to each cylinder of a dive lands.
class _Targets {
  _Targets(List<DiveTank> tanks)
    : _byId = {for (final tank in tanks) tank.id: tank},
      _breathing = breathingTanks(tanks),
      hasSuit = tanks.any((t) => !t.role.isBreathingGas);

  final Map<String, DiveTank> _byId;
  final List<DiveTank> _breathing;
  final bool hasSuit;

  /// Where each suit inflation bottle's switches land, worked out once per
  /// bottle rather than once per switch.
  final Map<String, String?> _resolved = {};
  late final DiveTank? _reference = sacReferenceTankOf(_breathing);

  /// The cylinder a switch to [tankId] counts against, or null to drop it.
  String? resolve(String tankId) {
    final tank = _byId[tankId];
    if (tank == null || tank.role.isBreathingGas) return tankId;
    return _resolved.putIfAbsent(tankId, () {
      final matches = _breathing.where((t) => _sameGas(t, tank)).toList();
      if (matches.isEmpty) return null;
      final reference = _reference;
      if (reference != null && matches.contains(reference)) {
        return reference.id;
      }
      return matches.first.id;
    });
  }

  static bool _sameGas(DiveTank a, DiveTank b) =>
      (a.gasMix.o2 - b.gasMix.o2).abs() <= sameGasTolerancePct &&
      (a.gasMix.he - b.gasMix.he).abs() <= sameGasTolerancePct;
}
