import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';

import '../../../tool/demo_data/src/seeders/gear_assemblies.dart';
import '../../../tool/demo_data/src/seeders/gear_catalog.dart';

void main() {
  final byKey = {for (final g in demoGear) g.key: g};

  List<EquipmentType> typesWith(KitUse use) => [
    for (final g in demoGear)
      if (g.uses.contains(use) || g.uses.contains(KitUse.always)) g.type,
  ];

  test('keys are unique', () {
    expect(byKey.length, demoGear.length);
  });

  test(
    'every regulator assembly has a first stage, a second stage and a hose',
    () {
      final regulators = demoAssemblies.where(
        (a) => byKey[a.parentKey]!.type == EquipmentType.regulator,
      );
      expect(regulators.length, greaterThanOrEqualTo(6));
      for (final a in regulators) {
        final types = [for (final (k, _) in a.parts) byKey[k]!.type];
        expect(types, contains(EquipmentType.firstStage), reason: a.parentKey);
        expect(types, contains(EquipmentType.secondStage), reason: a.parentKey);
        expect(types, contains(EquipmentType.hose), reason: a.parentKey);
      }
    },
  );

  test('some regulator carries an SPG and some a transmitter', () {
    final partTypes = [
      for (final a in demoAssemblies)
        for (final (k, _) in a.parts) byKey[k]!.type,
    ];
    expect(partTypes, contains(EquipmentType.instrument));
    expect(partTypes, contains(EquipmentType.transmitter));
    expect(partTypes, contains(EquipmentType.compass));
  });

  test(
    'every assembly part and install child exists, and no part is in two assemblies',
    () {
      final seen = <String>{};
      for (final a in demoAssemblies) {
        expect(byKey, contains(a.parentKey));
        for (final (k, _) in a.parts) {
          expect(byKey, contains(k));
          expect(seen.add(k), isTrue, reason: '$k is in two assemblies');
        }
      }
      for (final i in demoInstalls) {
        expect(byKey, contains(i.childKey));
        expect(byKey, contains(i.parentKey));
      }
    },
  );

  test('every equipment status appears', () {
    final statuses = {for (final g in demoGear) g.leaves?.status ?? g.status};
    expect(statuses, containsAll(EquipmentStatus.values));
  });

  test('the kit covers each kind of diving', () {
    expect(
      typesWith(KitUse.warm),
      containsAll([
        EquipmentType.mask,
        EquipmentType.fins,
        EquipmentType.wetsuit,
        EquipmentType.bcd,
        EquipmentType.regulator,
        EquipmentType.computer,
        EquipmentType.smb,
      ]),
    );
    expect(
      typesWith(KitUse.cold),
      containsAll([
        EquipmentType.drysuit,
        EquipmentType.undersuit,
        EquipmentType.hood,
        EquipmentType.gloves,
        EquipmentType.regulator,
        EquipmentType.light,
      ]),
    );
    final tech = typesWith(KitUse.tech);
    expect(
      tech,
      containsAll([
        EquipmentType.backplate,
        EquipmentType.wing,
        EquipmentType.harness,
        EquipmentType.tankBand,
        EquipmentType.reel,
      ]),
    );
    expect(
      tech.where((t) => t == EquipmentType.light).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      tech.where((t) => t == EquipmentType.regulator).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      tech.any((t) => t == EquipmentType.knife || t == EquipmentType.tool),
      isTrue,
    );
    final ccr = typesWith(KitUse.ccr);
    expect(
      ccr,
      containsAll([EquipmentType.rebreather, EquipmentType.regulator]),
    );
    final installTypes = [
      for (final i in demoInstalls) byKey[i.childKey]!.type,
    ];
    expect(
      installTypes.where((t) => t == EquipmentType.o2Cell).length,
      greaterThanOrEqualTo(3),
    );
    expect(installTypes, contains(EquipmentType.battery));
    expect(typesWith(KitUse.scooter), contains(EquipmentType.dpv));
    expect(
      typesWith(KitUse.photo),
      containsAll([
        EquipmentType.camera,
        EquipmentType.housing,
        EquipmentType.port,
        EquipmentType.strobe,
        EquipmentType.armClamp,
        EquipmentType.trayHandle,
      ]),
    );
  });

  test('cells and batteries are installs, never assembly parts', () {
    final parts = {
      for (final a in demoAssemblies)
        for (final (k, _) in a.parts) k,
    };
    for (final g in demoGear) {
      if (g.type == EquipmentType.o2Cell || g.type == EquipmentType.battery) {
        expect(parts, isNot(contains(g.key)), reason: g.key);
        expect(demoInstalls.map((i) => i.childKey), contains(g.key));
      }
    }
    final slots = [
      for (final i in demoInstalls)
        if (byKey[i.childKey]!.type == EquipmentType.o2Cell) i.slot,
    ];
    expect(slots, everyElement(inInclusiveRange(1, 3)));
  });

  test('hoses carry their type and length', () {
    for (final g in demoGear.where((g) => g.type == EquipmentType.hose)) {
      expect(
        ['lp', 'hp', 'lpi'],
        contains(g.attributes[EquipmentAttrKeys.hoseType]),
        reason: g.key,
      );
      expect(g.attributes['hose_length_m'], isA<num>(), reason: g.key);
    }
  });

  test('a replaced part leaves when its successor arrives', () {
    for (final g in demoGear.where((g) => g.replaces != null)) {
      final old = byKey[g.replaces!]!;
      expect(old.leaves, isNotNull, reason: g.key);
      expect(old.leaves!.at, g.bought, reason: g.key);
      expect(old.leaves!.offset, g.boughtOffset, reason: g.key);
    }
    expect(
      demoGear.where((g) => g.replaces != null).length,
      greaterThanOrEqualTo(4),
    );
  });

  test('product names are listed for the privacy check', () {
    for (final g in demoGear) {
      if (g.brand != null) expect(demoGearProductNames, contains(g.brand));
      if (g.model != null) expect(demoGearProductNames, contains(g.model));
    }
  });
}
