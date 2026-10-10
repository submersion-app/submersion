import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

/// Keeps a loop plan's two mandatory slots filled: at least one diluent and
/// exactly one oxygen supply (#3220).
///
/// Both are loop consumption only and never bailout gas, so neither can be
/// inferred from what the diver carries for open circuit; they are explicit
/// roles the plan always holds. Entering a loop mode, or loading a loop plan
/// saved before the slots existed, fills whatever is missing:
///
/// - Oxygen: the first pure-O2 cylinder not marked diluent is adopted once
///   (that is what an older plan meant by it); otherwise a placeholder is
///   added. Any further pure-O2 cylinder stays what it is -- bailout.
/// - Diluent: the cylinder(s) the segments already breathe are adopted (the
///   old inference, kept as the one convenience); with no segments yet, the
///   first cylinder that is not the oxygen slot; otherwise a placeholder on
///   air, for the diver to set.
///
/// Placeholders are a typical onboard 3 L / 200 bar cylinder.
class CcrLoopSlots {
  const CcrLoopSlots();

  static const placeholderVolumeLiters = 3.0;
  static const placeholderStartPressureBar = 200.0;

  /// [tanks] with both slots guaranteed, plus whether anything changed so a
  /// caller can tell an adopted/added slot from a plan that already had both.
  ({List<DiveTank> tanks, bool changed}) ensure(
    List<DiveTank> tanks, {
    required Iterable<PlanSegment> segments,
    required String Function() newId,
  }) {
    var result = List<DiveTank>.of(tanks);
    var changed = false;

    if (!result.any((t) => t.role == TankRole.oxygenSupply)) {
      final index = result.indexWhere(
        (t) => t.role != TankRole.diluent && isPureOxygen(t.gasMix),
      );
      if (index >= 0) {
        result[index] = result[index].copyWith(role: TankRole.oxygenSupply);
      } else {
        result.add(
          _placeholder(
            id: newId(),
            gasMix: const GasMix(o2: 100),
            role: TankRole.oxygenSupply,
            order: result.length,
          ),
        );
      }
      changed = true;
    }

    if (!result.any((t) => t.role == TankRole.diluent)) {
      final breathedIds = segments.map((s) => s.tankId).toSet();
      final eligible = result
          .where((t) => t.role != TankRole.oxygenSupply)
          .toList();
      final breathed = eligible
          .where((t) => breathedIds.contains(t.id))
          .toList();
      final adopt = breathed.isNotEmpty
          ? breathed
          : (segments.isEmpty && eligible.isNotEmpty ? [eligible.first] : []);
      if (adopt.isNotEmpty) {
        final adoptIds = adopt.map((t) => t.id).toSet();
        result = [
          for (final tank in result)
            adoptIds.contains(tank.id)
                ? tank.copyWith(role: TankRole.diluent)
                : tank,
        ];
      } else {
        result.add(
          _placeholder(
            id: newId(),
            gasMix: const GasMix(o2: 21),
            role: TankRole.diluent,
            order: result.length,
          ),
        );
      }
      changed = true;
    }

    return (tanks: result, changed: changed);
  }

  /// Whether [mix] is pure oxygen for slot purposes: 99.5 % and up, the
  /// same threshold the old derivation used.
  static bool isPureOxygen(GasMix mix) => mix.o2 >= 99.5;

  DiveTank _placeholder({
    required String id,
    required GasMix gasMix,
    required TankRole role,
    required int order,
  }) => DiveTank(
    id: id,
    volume: placeholderVolumeLiters,
    startPressure: placeholderStartPressureBar,
    gasMix: gasMix,
    role: role,
    order: order,
  );
}
