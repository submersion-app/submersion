import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';

/// The applier's read-only view of an existing dive_tanks row.
class ExistingTank {
  final String id;
  final TankRole tankRole;
  final double? volumeL;
  final double? workingPressureBar;
  final TankMaterial? tankMaterial;
  final double? startPressureBar;
  final String? tankName;
  final int tankOrder;

  /// The tank's gas, read only to offer a re-roled tank its configuration
  /// mix (see [OverwriteTank.gas]).
  final double o2Percent;
  final double hePercent;

  /// Where [tankRole] came from when no person chose it (issue #2595).
  final TankRoleSource? roleSource;

  const ExistingTank({
    required this.id,
    required this.tankRole,
    this.roleSource,
    this.volumeL,
    this.workingPressureBar,
    this.tankMaterial,
    this.startPressureBar,
    this.tankName,
    this.tankOrder = 0,
    this.o2Percent = 21,
    this.hePercent = 0,
  });

  /// The dive computer read the role off the transmitter's name, so it is a
  /// guess this applier may check against the configuration (issue #3307).
  bool get roleNameDerived => roleSource == TankRoleSource.transmitterName;
}

/// A gas mix as oxygen and helium percentages.
typedef GasPercentages = ({double o2, double he});

sealed class CylinderConfigOp {
  const CylinderConfigOp();
}

/// Create a new dive_tanks row from [item] at [tankOrder].
class InsertTank extends CylinderConfigOp {
  final CylinderConfigItem item;
  final int tankOrder;

  const InsertTank({required this.item, required this.tankOrder});
}

/// Fill columns that are NULL on an existing dive_tanks row. Every field here
/// is nullable and null means "leave this column alone".
///
/// There are deliberately no o2Percent or hePercent fields. dive_tanks
/// defaults them to 21.0 and 0.0, so a tank reading air is indistinguishable
/// from a tank nobody filled in -- there is no null to test against, and
/// therefore no honest way to detect "unset". Omitting the fields makes
/// overwriting a gas mix unexpressible rather than merely discouraged.
/// Absent gas on a dive is a nuisance; wrong gas is a safety-relevant
/// falsehood in a logbook divers plan future dives from.
class FillTank extends CylinderConfigOp {
  final String tankId;
  final double? volumeL;
  final double? workingPressureBar;
  final TankMaterial? tankMaterial;
  final double? startPressureBar;
  final String? tankName;

  /// The configuration confirms a role the dive computer read off the
  /// transmitter's name, so it stops being a guess (issue #3307). Clears a
  /// marker, never a role, so it needs no consent.
  final bool clearRoleSource;

  const FillTank({
    required this.tankId,
    this.volumeL,
    this.workingPressureBar,
    this.tankMaterial,
    this.startPressureBar,
    this.tankName,
    this.clearRoleSource = false,
  });

  bool get isEmpty =>
      volumeL == null &&
      workingPressureBar == null &&
      tankMaterial == null &&
      startPressureBar == null &&
      tankName == null &&
      !clearRoleSource;
}

/// One spec column whose value on the dive differs from the configuration.
class SpecChange<T> {
  final T from;
  final T to;

  const SpecChange(this.from, this.to);
}

/// Replace spec columns that already hold a DIFFERENT value on an existing
/// row. Every field is nullable and null means "this column already agrees".
///
/// Never part of [CylinderConfigPlan.ops]: a FillTank only writes into a
/// gap, but this replaces something the diver or a dive computer put there,
/// so callers show the diver these changes and apply them only on consent
/// (issue #2563). Like [FillTank] it never replaces a gas mix the diver or
/// a dive computer put there (see [gas] for the one defaulted case), and it
/// has no start pressure either: that is a reading of this dive, not a
/// property of the cylinder a configuration describes.
///
/// [role] is set only on a tank whose role the dive computer read off the
/// transmitter's name, where the configuration says the cylinder is
/// something else (issue #3307). [gas] can only accompany it: such a tank's
/// mix is not the computer's either (a Shearwater transmitter reports none),
/// but the default the importer gave the guessed role, such as 100% for an
/// oxygen supply, so a bailout re-roled from O2 must not keep it. The plan's
/// ops already treat that tank as the configuration's cylinder (its fill,
/// and no duplicate insert), so a caller applies the ops together with the
/// overwrites or not at all.
class OverwriteTank extends CylinderConfigOp {
  final String tankId;

  /// The role the tank holds on the dive now.
  final TankRole tankRole;
  final SpecChange<TankRole>? role;
  final SpecChange<GasPercentages>? gas;
  final SpecChange<double>? volumeL;
  final SpecChange<double>? workingPressureBar;
  final SpecChange<TankMaterial>? tankMaterial;
  final SpecChange<String>? tankName;

  const OverwriteTank({
    required this.tankId,
    required this.tankRole,
    this.role,
    this.gas,
    this.volumeL,
    this.workingPressureBar,
    this.tankMaterial,
    this.tankName,
  });

  bool get isEmpty =>
      role == null &&
      gas == null &&
      volumeL == null &&
      workingPressureBar == null &&
      tankMaterial == null &&
      tankName == null;

  /// Whether the cylinder itself changes, not just its label. A tank preset
  /// name no longer describes a cylinder whose size or material changed.
  bool get changesCylinder =>
      volumeL != null || workingPressureBar != null || tankMaterial != null;
}

/// The result of planning an apply: the operations to persist, the
/// overwrites to offer the diver, plus the counts a caller reports back.
class CylinderConfigPlan {
  final List<CylinderConfigOp> ops;

  /// Differences on claimed tanks that [ops] deliberately leaves alone.
  final List<OverwriteTank> overwrites;
  final int insertedCount;
  final int keptCount;

  const CylinderConfigPlan({
    required this.ops,
    this.overwrites = const [],
    required this.insertedCount,
    required this.keptCount,
  });

  bool get isNoOp => insertedCount == 0 && keptCount == 0;
}

/// Merges a cylinder configuration into a dive's existing cylinders.
///
/// Pure: no database, no DateTime.now(). Callers persist the returned ops.
/// Mirrors ServiceDueEngine, so the merge rules can be tested exhaustively
/// without a database fixture.
class CylinderConfigApplier {
  const CylinderConfigApplier();

  // Specs reach both sides through unit conversion (a cylinder entered in
  // cubic feet or psi), so an exact comparison would offer to "change" a
  // cylinder to the value it already holds.
  static const _volumeToleranceL = 0.01;
  static const _pressureToleranceBar = 0.5;

  /// A change only when both sides hold a value: a null on the dive is a
  /// fill, and a null in the configuration has nothing to offer.
  static SpecChange<double>? _differs(
    double? current,
    double? wanted,
    double tolerance,
  ) {
    if (current == null || wanted == null) return null;
    if ((current - wanted).abs() <= tolerance) return null;
    return SpecChange(current, wanted);
  }

  static const _gasTolerancePercent = 0.5;

  static SpecChange<GasPercentages>? _gasDiffers(
    ExistingTank tank,
    CylinderConfigItem item,
  ) {
    final from = (o2: tank.o2Percent, he: tank.hePercent);
    final to = (o2: item.o2Percent, he: item.hePercent);
    // The role source says how the role was found, not the mix: a diver who
    // entered a mix on the tank keeps it. Only the importer's default for
    // the guessed role (100% for an oxygen supply, air otherwise) goes.
    final defaulted = (
      o2: tank.tankRole == TankRole.oxygenSupply ? 100.0 : 21.0,
      he: 0.0,
    );
    if (!_sameGas(from, defaulted) || _sameGas(from, to)) return null;
    return SpecChange(from, to);
  }

  static bool _sameGas(GasPercentages a, GasPercentages b) =>
      (a.o2 - b.o2).abs() <= _gasTolerancePercent &&
      (a.he - b.he).abs() <= _gasTolerancePercent;

  /// How a tank's known specs compare with a configuration item's: any
  /// column known on both sides and different contradicts; otherwise a
  /// volume known on both sides and equal agrees; otherwise nothing is
  /// known. Only the volume can agree: the oxygen cylinder and the bailout
  /// of a CCR set are routinely both aluminium at the same pressure, so a
  /// matching material or pressure tells them apart no better than a role.
  static _Fit _fit(ExistingTank tank, CylinderConfigItem item) {
    final volume = _compare(tank.volumeL, item.volumeL, _volumeToleranceL);
    final pressure = _compare(
      tank.workingPressureBar,
      item.workingPressureBar,
      _pressureToleranceBar,
    );
    final material = tank.tankMaterial == null || item.tankMaterial == null
        ? null
        : tank.tankMaterial == item.tankMaterial;
    if ([volume, pressure, material].contains(false)) return _Fit.contradicts;
    return volume == true ? _Fit.agrees : _Fit.unknown;
  }

  /// Whether two values agree within [tolerance], or null when either side
  /// is unknown.
  static bool? _compare(double? a, double? b, double tolerance) =>
      a == null || b == null ? null : (a - b).abs() <= tolerance;

  /// Matches every item to an existing tank, or to none (an insert).
  ///
  /// Roles are not unique (a CCR diver routinely carries two bailout
  /// cylinders), so items claim tanks greedily in order: that is what makes
  /// "config has 2 bailouts, dive already has 1" resolve to keep-one-add-one
  /// rather than duplicating or clobbering.
  ///
  /// A role the dive computer read off a transmitter's name is a guess
  /// (issue #3307): a bailout named "OC" arrives as the oxygen supply. Such
  /// a tank is checked against the configuration in passes of falling
  /// evidence, and may be claimed by an item of another role, which the
  /// plan then offers the diver as a role change:
  ///
  /// 1. Same role, without contradicting specs: a fitting size first, then a
  ///    role the diver set, so a guessed one is what is left over.
  /// 2. A name-derived tank left over whose specs fit another item.
  /// 3. Same role, specs contradicting (offered as an overwrite, as today).
  /// 4. A name-derived tank left over while its role's items are all
  ///    claimed: the configuration has one cylinder of that role fewer than
  ///    the dive, and one of another role more. Earlier tanks were claimed
  ///    first, so it is the later of two same-role tanks that is offered.
  Map<CylinderConfigItem, ExistingTank> _match(
    List<CylinderConfigItem> ordered,
    List<ExistingTank> existing,
  ) {
    final matches = <CylinderConfigItem, ExistingTank>{};
    final claimed = <String>{};

    void claimEach(
      ExistingTank? Function(CylinderConfigItem, List<ExistingTank>) pick,
    ) {
      for (final item in ordered) {
        if (matches.containsKey(item)) continue;
        final free = [
          for (final tank in existing)
            if (!claimed.contains(tank.id)) tank,
        ];
        final tank = pick(item, free);
        if (tank == null) continue;
        matches[item] = tank;
        claimed.add(tank.id);
      }
    }

    claimEach((item, free) {
      final candidates = [
        for (final tank in free)
          if (tank.tankRole == item.tankRole &&
              !(tank.roleNameDerived && _fit(tank, item) == _Fit.contradicts))
            tank,
      ];
      return candidates
              .where((t) => _fit(t, item) == _Fit.agrees)
              .firstOrNull ??
          candidates.where((t) => !t.roleNameDerived).firstOrNull ??
          candidates.firstOrNull;
    });
    claimEach(
      (item, free) => free
          .where(
            (t) =>
                t.roleNameDerived &&
                t.tankRole != item.tankRole &&
                _fit(t, item) == _Fit.agrees,
          )
          .firstOrNull,
    );
    claimEach(
      (item, free) =>
          free.where((t) => t.tankRole == item.tankRole).firstOrNull,
    );
    final configRoles = {for (final item in ordered) item.tankRole};
    claimEach(
      (item, free) => free
          .where(
            (t) =>
                t.roleNameDerived &&
                t.tankRole != item.tankRole &&
                configRoles.contains(t.tankRole) &&
                _fit(t, item) == _Fit.unknown,
          )
          .firstOrNull,
    );
    return matches;
  }

  CylinderConfigPlan plan({
    required List<ExistingTank> existing,
    required List<CylinderConfigItem> items,
  }) {
    final ordered = [...items]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final matches = _match(ordered, existing);

    final ops = <CylinderConfigOp>[];
    final overwrites = <OverwriteTank>[];
    var inserted = 0;
    var kept = 0;

    var nextOrder = existing.isEmpty
        ? 0
        : existing.map((t) => t.tankOrder).reduce((a, b) => a > b ? a : b) + 1;

    for (final item in ordered) {
      final match = matches[item];
      if (match == null) {
        ops.add(InsertTank(item: item, tankOrder: nextOrder));
        nextOrder++;
        inserted++;
        continue;
      }

      kept++;
      final roleChanges = match.tankRole != item.tankRole;

      final fill = FillTank(
        tankId: match.id,
        volumeL: match.volumeL == null ? item.volumeL : null,
        workingPressureBar: match.workingPressureBar == null
            ? item.workingPressureBar
            : null,
        tankMaterial: match.tankMaterial == null ? item.tankMaterial : null,
        startPressureBar: match.startPressureBar == null
            ? item.defaultStartPressureBar
            : null,
        tankName: match.tankName == null ? item.label : null,
        // A size that fits confirms a name-derived role; a match on role
        // alone is the same guess counted twice.
        clearRoleSource:
            !roleChanges &&
            match.roleNameDerived &&
            _fit(match, item) == _Fit.agrees,
      );
      if (!fill.isEmpty) ops.add(fill);

      final label = item.label?.trim();
      final overwrite = OverwriteTank(
        tankId: match.id,
        tankRole: match.tankRole,
        role: roleChanges ? SpecChange(match.tankRole, item.tankRole) : null,
        gas: roleChanges ? _gasDiffers(match, item) : null,
        volumeL: _differs(match.volumeL, item.volumeL, _volumeToleranceL),
        workingPressureBar: _differs(
          match.workingPressureBar,
          item.workingPressureBar,
          _pressureToleranceBar,
        ),
        tankMaterial:
            match.tankMaterial != null &&
                item.tankMaterial != null &&
                match.tankMaterial != item.tankMaterial
            ? SpecChange(match.tankMaterial!, item.tankMaterial!)
            : null,
        tankName:
            match.tankName != null &&
                label != null &&
                label.isNotEmpty &&
                match.tankName!.trim() != label
            ? SpecChange(match.tankName!, label)
            : null,
      );
      if (!overwrite.isEmpty) overwrites.add(overwrite);
    }

    return CylinderConfigPlan(
      ops: ops,
      overwrites: overwrites,
      insertedCount: inserted,
      keptCount: kept,
    );
  }
}

enum _Fit { agrees, unknown, contradicts }
