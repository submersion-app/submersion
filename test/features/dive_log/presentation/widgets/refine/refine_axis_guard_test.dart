import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_conditions_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_custom_fields_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_date_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_gas_equipment_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_location_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_organization_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_people_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_rules_group.dart';

/// No search capability lost (#2773, spec section 9 item 7): every
/// DiveFilterState field is edited by exactly one Refine panel group, or is
/// on this short list with the reason it has no control.
const _noControl = {
  'buddyId', // set by the buddy page's "View all"; removable as a chip
  'diveIds', // set by Connections and other handoffs; removable as a chip
  'siteIds', // set by Explore's place lowering; removable as a chip
  'axesSuspended', // the dive search row's scope toggle owns it
};

const _groups = [
  RefineRulesGroup.fields,
  RefineDateGroup.fields,
  RefineLocationGroup.fields,
  RefineConditionsGroup.fields,
  RefineGasEquipmentGroup.fields,
  RefinePeopleGroup.fields,
  RefineOrganizationGroup.fields,
  RefineCustomFieldsGroup.fields,
];

void main() {
  test('every DiveFilterState field has a control or a reason', () {
    final source = File(
      p.join(
        'lib',
        'features',
        'dive_log',
        'domain',
        'models',
        'dive_filter_state.dart',
      ),
    ).readAsStringSync();
    final fields = RegExp(
      r'^  final [\w<>?, ]+ (\w+);',
      multiLine: true,
    ).allMatches(source).map((m) => m[1]!).toSet();
    expect(fields, contains('query'));
    final covered = {..._groups.expand((g) => g), ..._noControl};
    expect(fields.difference(covered), isEmpty, reason: 'no control');
    expect(covered.difference(fields), isEmpty, reason: 'stale names');
  });

  test('no field is edited by two groups', () {
    final seen = <String>{};
    for (final field in _groups.expand((g) => g)) {
      expect(seen.add(field), isTrue, reason: '$field is in two groups');
    }
    expect(seen.intersection(_noControl), isEmpty);
  });
}
