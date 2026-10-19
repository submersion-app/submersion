import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_field_value.dart';
import 'package:submersion/features/rules/domain/rule_value_kind.dart';
import 'package:submersion/features/rules/domain/site_rule_field.dart';

Object _sample(BulkField f, String key) => switch (diveFieldKind(f)) {
  RuleValueKind.text || RuleValueKind.entityRef => 'x',
  RuleValueKind.enumName => diveFieldEnumValues(f).first,
  RuleValueKind.boolean => true,
  RuleValueKind.rating => 4,
  RuleValueKind.number => diveFieldIsInteger(f) ? 3 : 3.5,
};

void main() {
  test('settable fields exclude the role and notes lanes', () {
    expect(kRuleSettableDiveFields, isNot(contains(BulkField.diverRole)));
    expect(kRuleSettableDiveFields, isNot(contains(BulkField.notes)));
    expect(kRuleSettableDiveFields, contains(BulkField.gradientFactorLow));
    expect(kRuleSettableDiveFields, contains(BulkField.diluentGas));
  });

  test('every settable field builds a non-empty companion', () {
    for (final f in kRuleSettableDiveFields) {
      final values = {for (final k in diveFieldValueKeys(f)) k: _sample(f, k)};
      final c = diveCompanionFor(SetDiveFieldAction(f, values));
      expect(c.toColumns(false), isNotEmpty, reason: f.name);
    }
  });

  test('each field\'s display column is the one its first value writes', () {
    expect(
      diveFieldColumn(BulkField.scrubberDuration),
      'scrubber_duration_minutes',
    );
    expect(diveFieldColumn(BulkField.visibility), 'visibility_meters');
    expect(diveFieldColumn(BulkField.diveCenter), 'dive_center_id');
    for (final f in kRuleSettableDiveFields) {
      final key = diveFieldValueKeys(f).first;
      final written = diveCompanionFor(
        SetDiveFieldAction(f, {key: _sample(f, key)}),
      ).toColumns(false);
      expect(written.keys, contains(diveFieldColumn(f)), reason: f.name);
    }
  });

  test('a field that writes no column has no display column', () {
    // diverRole is not settable here, but a newer version's change row
    // can name it; reading it must not throw inside the change list.
    expect(diveFieldColumn(BulkField.diverRole), isNull);
  });

  test('visibility writes the three columns and clears the legacy bucket', () {
    final cols = diveCompanionFor(
      const SetDiveFieldAction(BulkField.visibility, {
        'visibilityMeters': 20.0,
      }),
    ).toColumns(false);
    expect(
      cols.keys,
      containsAll([
        'visibility_meters',
        'visibility_min_meters',
        'visibility_max_meters',
        'visibility',
      ]),
    );
  });

  test('diluent writes O2 and He', () {
    final cols = diveCompanionFor(
      const SetDiveFieldAction(BulkField.diluentGas, {
        'diluentO2': 21.0,
        'diluentHe': 35.0,
      }),
    ).toColumns(false);
    expect(cols.keys, containsAll(['diluent_o2', 'diluent_he']));
  });

  test('swell height is stored as given, in metres', () {
    final cols = diveCompanionFor(
      const SetDiveFieldAction(BulkField.swellHeight, {'swellHeight': 0.9144}),
    ).toColumns(false);
    expect((cols['swell_height']! as Variable).value, 0.9144);
    expect(diveFieldUnit(BulkField.swellHeight), RuleUnit.depth);
  });

  test('units for fields that convert', () {
    expect(diveFieldUnit(BulkField.altitude), RuleUnit.altitude);
    expect(diveFieldUnit(BulkField.windSpeed), RuleUnit.windSpeed);
    expect(diveFieldUnit(BulkField.surfacePressure), RuleUnit.millibar);
    expect(diveFieldUnit(BulkField.surfaceInterval), RuleUnit.seconds);
    expect(diveFieldUnit(BulkField.boatName), RuleUnit.none);
    expect(siteFieldUnit(SiteRuleField.maxDepth), RuleUnit.depth);
    expect(siteFieldUnit(SiteRuleField.altitude), RuleUnit.altitude);
    expect(siteFieldUnit(SiteRuleField.country), RuleUnit.none);
  });

  test('dive mode stores its code and entity fields are refs', () {
    expect(diveFieldKind(BulkField.diveMode), RuleValueKind.enumName);
    expect(diveFieldEnumValues(BulkField.diveMode), contains('ccr'));
    expect(diveFieldKind(BulkField.diveCenter), RuleValueKind.entityRef);
    expect(diveFieldKind(BulkField.trip), RuleValueKind.entityRef);
  });
}
