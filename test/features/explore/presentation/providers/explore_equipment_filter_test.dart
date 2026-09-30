import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/explore/presentation/providers/explore_subject_providers.dart';

/// Explore's equipment answer goes through the equipment list's filter,
/// whose unset status hides retired and sold gear. A status the sentence
/// names must become that axis, or "my retired regulators" finds nothing.
void main() {
  ConditionNode status(String name) => ConditionNode(
    FieldPath(const ['status']),
    QueryOp.inList,
    ListValue([EnumValue(name)]),
  );
  final regulators = ConditionNode(
    FieldPath(const ['type']),
    QueryOp.inList,
    ListValue(const [EnumValue('regulator')]),
  );

  test('a named status becomes the status axis', () {
    final f = exploreEquipmentFilter(status('retired'));
    expect(f.status, EquipmentStatus.retired);
    expect(f.query, isNull);
  });

  test('beside other conditions it is lifted out of them', () {
    final f = exploreEquipmentFilter(AndNode([regulators, status('sold')]));
    expect(f.status, EquipmentStatus.sold);
    expect(f.query, regulators);
  });

  test('no status keeps the default view and the whole query', () {
    final f = exploreEquipmentFilter(regulators);
    expect(f.status, isNull);
    expect(f.query, regulators);
  });

  test('a negated or several statuses stay in the query', () {
    final not = NotNode(status('retired'));
    expect(exploreEquipmentFilter(not).status, isNull);
    expect(exploreEquipmentFilter(not).query, not);
    final two = ConditionNode(
      FieldPath(const ['status']),
      QueryOp.inList,
      ListValue(const [EnumValue('retired'), EnumValue('sold')]),
    );
    expect(exploreEquipmentFilter(two).status, isNull);
  });
}
