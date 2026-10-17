import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/domain/services/cylinder_config_applier.dart';

/// A Shearwater in CCR mode derives a transmitter's role from the first
/// letter of its name, so a bailout named "OC" arrives as the oxygen supply.
/// Applying a cylinder configuration checks such roles (issue #3307).
void main() {
  final now = DateTime.utc(2026, 10, 16);
  const applier = CylinderConfigApplier();

  CylinderConfigItem cfg({
    required String id,
    required TankRole role,
    int order = 0,
    double? volume,
    double? pressure,
    TankMaterial? material,
  }) => CylinderConfigItem(
    id: id,
    configId: 'c1',
    sortOrder: order,
    tankRole: role,
    o2Percent: role == TankRole.oxygenSupply ? 100 : 21,
    hePercent: 0,
    volumeL: volume,
    workingPressureBar: pressure,
    tankMaterial: material,
    createdAt: now,
    updatedAt: now,
  );

  ExistingTank tank({
    required String id,
    required TankRole role,
    bool nameDerived = true,
    double? volume,
    double? pressure,
    TankMaterial? material,
    int order = 0,
  }) => ExistingTank(
    id: id,
    tankRole: role,
    roleSource: nameDerived ? TankRoleSource.transmitterName : null,
    volumeL: volume,
    workingPressureBar: pressure,
    tankMaterial: material,
    tankOrder: order,
    // As the importer leaves it: a transmitter reports no mix, so an
    // oxygen supply gets 100% and everything else air.
    o2Percent: role == TankRole.oxygenSupply ? 100 : 21,
  );

  // The usual CCR configuration: O2, diluent and one bailout.
  final ccrConfig = [
    cfg(id: 'o2', role: TankRole.oxygenSupply, order: 0, volume: 3),
    cfg(id: 'dil', role: TankRole.diluent, order: 1, volume: 3),
    cfg(id: 'bo', role: TankRole.bailout, order: 2, volume: 5.7),
  ];

  List<OverwriteTank> roleChanges(CylinderConfigPlan plan) =>
      plan.overwrites.where((o) => o.role != null).toList();

  group('a surplus name-derived tank', () {
    test('is offered the role of a config cylinder with no match', () {
      // "O2", "Dil" and the "OC" bailout: two tanks claim the O2 role.
      final plan = applier.plan(
        existing: [
          tank(id: 't1', role: TankRole.oxygenSupply, order: 0),
          tank(id: 't2', role: TankRole.diluent, order: 1),
          tank(id: 't3', role: TankRole.oxygenSupply, order: 2),
        ],
        items: ccrConfig,
      );

      // The bailout is no longer duplicated.
      expect(plan.ops.whereType<InsertTank>(), isEmpty);
      expect(plan.insertedCount, 0);
      expect(plan.keptCount, 3);

      // The later of the two O2 tanks is the one offered the bailout role.
      final change = roleChanges(plan).single;
      expect(change.tankId, 't3');
      expect(change.tankRole, TankRole.oxygenSupply);
      expect(change.role?.from, TankRole.oxygenSupply);
      expect(change.role?.to, TankRole.bailout);
      // The 100% the importer gave the guessed O2 role goes with it.
      expect(change.gas?.from, (o2: 100.0, he: 0.0));
      expect(change.gas?.to, (o2: 21.0, he: 0.0));
    });

    test('keeps a gas mix the diver entered', () {
      final plan = applier.plan(
        existing: [
          tank(id: 't1', role: TankRole.oxygenSupply, order: 0),
          tank(id: 't2', role: TankRole.diluent, order: 1),
          const ExistingTank(
            id: 't3',
            tankRole: TankRole.oxygenSupply,
            roleSource: TankRoleSource.transmitterName,
            tankOrder: 2,
            o2Percent: 50,
          ),
        ],
        items: ccrConfig,
      );

      final change = roleChanges(plan).single;
      expect(change.tankId, 't3');
      expect(change.role?.to, TankRole.bailout);
      expect(change.gas, isNull);
    });

    test('a role the diver set keeps the match over a guessed one', () {
      // The guessed "OC" tank comes first; the diver set the other one.
      final plan = applier.plan(
        existing: [
          tank(id: 't1', role: TankRole.oxygenSupply, order: 0),
          tank(id: 't2', role: TankRole.diluent, order: 1),
          tank(
            id: 't3',
            role: TankRole.oxygenSupply,
            nameDerived: false,
            order: 2,
          ),
        ],
        items: ccrConfig,
      );

      final change = roleChanges(plan).single;
      expect(change.tankId, 't1');
      expect(change.role?.to, TankRole.bailout);
      expect(plan.ops.whereType<InsertTank>(), isEmpty);
    });

    test('fills the specs of the config cylinder it is offered', () {
      final plan = applier.plan(
        existing: [
          tank(id: 't1', role: TankRole.oxygenSupply, order: 0),
          tank(id: 't2', role: TankRole.diluent, order: 1),
          tank(id: 't3', role: TankRole.oxygenSupply, order: 2),
        ],
        items: ccrConfig,
      );

      final fill = plan.ops.whereType<FillTank>().singleWhere(
        (f) => f.tankId == 't3',
      );
      expect(fill.volumeL, 5.7);
    });

    test('a size that fits a different config cylinder decides which', () {
      // The first O2-tagged tank is the 5.7 L bailout; the second is 3 L.
      final plan = applier.plan(
        existing: [
          tank(id: 't1', role: TankRole.oxygenSupply, volume: 5.7),
          tank(id: 't2', role: TankRole.diluent, order: 1),
          tank(id: 't3', role: TankRole.oxygenSupply, volume: 3, order: 2),
        ],
        items: ccrConfig,
      );

      final change = roleChanges(plan).single;
      expect(change.tankId, 't1');
      expect(change.role?.to, TankRole.bailout);
      expect(plan.ops.whereType<InsertTank>(), isEmpty);
    });

    test('a size that contradicts its own role is re-roled to the fit', () {
      // Only one O2-tagged tank, and it is the 5.7 L bailout: the O2
      // supply in the configuration has no transmitter on this dive.
      final plan = applier.plan(
        existing: [
          tank(id: 't1', role: TankRole.oxygenSupply, volume: 5.7),
          tank(id: 't2', role: TankRole.diluent, order: 1),
        ],
        items: ccrConfig,
      );

      final change = roleChanges(plan).single;
      expect(change.tankId, 't1');
      expect(change.role?.to, TankRole.bailout);
      final insert = plan.ops.whereType<InsertTank>().single;
      expect(insert.item.tankRole, TankRole.oxygenSupply);
    });

    test('keeps its role when the config has no cylinder of that role', () {
      // No O2 item: nothing says the O2-tagged tank is one too many.
      final plan = applier.plan(
        existing: [
          tank(id: 't1', role: TankRole.oxygenSupply),
          tank(id: 't2', role: TankRole.diluent, order: 1),
        ],
        items: [
          cfg(id: 'dil', role: TankRole.diluent),
          cfg(id: 'bo', role: TankRole.bailout, order: 1),
        ],
      );

      expect(roleChanges(plan), isEmpty);
      expect(
        plan.ops.whereType<InsertTank>().single.item.tankRole,
        TankRole.bailout,
      );
    });
  });

  test('a role the diver set is never offered a change', () {
    final plan = applier.plan(
      existing: [
        tank(id: 't1', role: TankRole.oxygenSupply, nameDerived: false),
        tank(id: 't2', role: TankRole.diluent, nameDerived: false, order: 1),
        tank(
          id: 't3',
          role: TankRole.oxygenSupply,
          nameDerived: false,
          volume: 5.7,
          order: 2,
        ),
      ],
      items: ccrConfig,
    );

    expect(roleChanges(plan), isEmpty);
    expect(
      plan.ops.whereType<InsertTank>().single.item.tankRole,
      TankRole.bailout,
    );
    expect(
      plan.ops.whereType<FillTank>().where((f) => f.clearRoleSource),
      isEmpty,
    );
  });

  group('confirming a name-derived role', () {
    test('a matching size clears the role source', () {
      final plan = applier.plan(
        existing: [
          tank(id: 't1', role: TankRole.oxygenSupply, volume: 3),
          tank(id: 't2', role: TankRole.diluent, volume: 3, order: 1),
        ],
        items: ccrConfig,
      );

      final cleared = plan.ops
          .whereType<FillTank>()
          .where((f) => f.clearRoleSource)
          .map((f) => f.tankId);
      expect(cleared, unorderedEquals(['t1', 't2']));
      expect(roleChanges(plan), isEmpty);
    });

    test('a match on role alone is not a confirmation', () {
      final plan = applier.plan(
        existing: [
          tank(id: 't1', role: TankRole.oxygenSupply),
          tank(id: 't2', role: TankRole.diluent, order: 1),
        ],
        items: ccrConfig,
      );

      expect(
        plan.ops.whereType<FillTank>().where((f) => f.clearRoleSource),
        isEmpty,
      );
    });

    test('a matching material or pressure alone is not a confirmation', () {
      // An O2 cylinder and a bailout are routinely both aluminium.
      final plan = applier.plan(
        existing: [
          tank(
            id: 't1',
            role: TankRole.oxygenSupply,
            pressure: 207,
            material: TankMaterial.aluminum,
          ),
        ],
        items: [
          cfg(
            id: 'o2',
            role: TankRole.oxygenSupply,
            pressure: 207,
            material: TankMaterial.aluminum,
          ),
        ],
      );

      expect(
        plan.ops.whereType<FillTank>().where((f) => f.clearRoleSource),
        isEmpty,
      );
    });

    test('a contradicting size never confirms the role', () {
      // The only diluent-tagged tank is 11 L against a 3 L diluent: it is
      // still matched (the specs are offered as an overwrite) but stays
      // unconfirmed.
      final plan = applier.plan(
        existing: [tank(id: 't1', role: TankRole.diluent, volume: 11)],
        items: [cfg(id: 'dil', role: TankRole.diluent, volume: 3)],
      );

      expect(plan.ops.whereType<InsertTank>(), isEmpty);
      expect(plan.overwrites.single.volumeL?.to, 3);
      expect(plan.overwrites.single.role, isNull);
      expect(
        plan.ops.whereType<FillTank>().where((f) => f.clearRoleSource),
        isEmpty,
      );
    });
  });
}
