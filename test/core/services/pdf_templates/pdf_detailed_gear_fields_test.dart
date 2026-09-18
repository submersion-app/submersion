import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The printed logbook keeps an assembly's parts under the assembly
/// (issue #1487): indented, in template order, after the row they belong to.
/// Set gear and hand-added gear print as one arranged list, with the sets
/// named on their own row above it (#2031).
void main() {
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Cold water reg',
    type: EquipmentType.regulator,
  );
  const hose = EquipmentItem(
    id: 'hose',
    name: 'Long hose',
    type: EquipmentType.hose,
  );
  const mask = EquipmentItem(
    id: 'mask',
    name: 'Mask',
    type: EquipmentType.mask,
  );

  final template = PdfTemplateDetailed();
  const units = UnitFormatter(AppSettings());

  test('parts print indented under their assembly, with their type', () {
    final dive = Dive(
      id: 'dive-1',
      diveNumber: 1,
      dateTime: DateTime(2026, 3, 28, 10, 0),
      notes: '',
      gear: gearLinksFor(
        const [reg, hose, mask],
        const [GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg')],
      ),
    );
    final fields = template.equipmentFieldsForTest(
      dive,
      units: units,
      arrangement: EquipmentArrangement.defaults,
    );
    final labels = fields.map((f) => f.label).toList();
    final regAt = labels.indexOf('Regulator');
    expect(regAt, greaterThanOrEqualTo(0));
    expect(labels[regAt + 1], '  Hose');
    expect(fields[regAt + 1].value, 'Long hose');
    // The part is not also printed as a top-level row.
    expect(labels.where((l) => l == 'Hose'), isEmpty);
  });

  const fins = EquipmentItem(
    id: 'fins',
    name: 'Jets',
    type: EquipmentType.fins,
  );
  // The diver applied the winter set, then swapped its mask for one added
  // by hand: the reg and fins came from the set, the mask did not.
  final swapped = Dive(
    id: 'dive-2',
    diveNumber: 2,
    dateTime: DateTime(2026, 3, 29, 10, 0),
    notes: '',
    gear: gearLinksFor(
      const [reg, fins, mask],
      const [
        GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
        GearProvenance(equipmentId: 'fins', viaSetId: 'winter'),
      ],
    ),
  );

  test('hand-added gear prints among the set\'s gear, not after it', () {
    final labels = template
        .equipmentFieldsForTest(
          swapped,
          units: units,
          arrangement: EquipmentArrangement.defaults,
        )
        .map((f) => f.label)
        .toList();
    // Alphabetical by type across the whole dive; the old per-set runs
    // printed Fins, Regulator, then the loose Mask.
    expect(labels, ['Fins', 'Mask', 'Regulator']);
  });

  test('the sets the gear came from print on one row above it', () {
    final fields = template.equipmentFieldsForTest(
      swapped,
      units: units,
      arrangement: EquipmentArrangement.defaults,
      setNamesById: const {'winter': 'Winter kit', 'other': 'Unused'},
    );
    expect(fields.first, (label: 'Set', value: 'Winter kit'));
    expect(fields.skip(1).map((f) => f.label), ['Fins', 'Mask', 'Regulator']);
  });

  test('several sets print as one comma-separated row', () {
    final dive = Dive(
      id: 'dive-3',
      diveNumber: 3,
      dateTime: DateTime(2026, 3, 30, 10, 0),
      notes: '',
      gear: gearLinksFor(
        const [reg, fins],
        const [
          GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
          GearProvenance(equipmentId: 'fins', viaSetId: 'photo'),
        ],
      ),
    );
    final fields = template.equipmentFieldsForTest(
      dive,
      units: units,
      arrangement: EquipmentArrangement.defaults,
      setNamesById: const {'winter': 'Winter kit', 'photo': 'Photo rig'},
    );
    expect(fields.first, (label: 'Sets', value: 'Winter kit, Photo rig'));
  });

  test('a set with no name on file prints no set row', () {
    // Deleted since the dive was logged, or the lookup failed: the document
    // omits the row rather than printing an id the reader cannot use.
    final labels = template
        .equipmentFieldsForTest(
          swapped,
          units: units,
          arrangement: EquipmentArrangement.defaults,
        )
        .map((f) => f.label);
    expect(labels, isNot(contains('Set')));
  });

  test('a set with a blank name prints no set row', () {
    // The set editor trims a name of spaces to '' on save.
    final labels = template
        .equipmentFieldsForTest(
          swapped,
          units: units,
          arrangement: EquipmentArrangement.defaults,
          setNamesById: const {'winter': '  '},
        )
        .map((f) => f.label);
    expect(labels, isNot(contains('Set')));
  });
}
