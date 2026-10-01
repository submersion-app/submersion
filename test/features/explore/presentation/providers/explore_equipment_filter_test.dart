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

  test('two other conditions stay joined once the status is lifted', () {
    final named = ConditionNode(
      FieldPath(const ['name']),
      QueryOp.contains,
      const StringValue('apeks'),
    );
    final f = exploreEquipmentFilter(
      AndNode([regulators, status('retired'), named]),
    );
    expect(f.status, EquipmentStatus.retired);
    expect(f.query, AndNode([regulators, named]));
  });

  test('no status keeps the default view and the whole query', () {
    final f = exploreEquipmentFilter(regulators);
    expect(f.status, isNull);
    expect(f.allStatuses, isFalse);
    expect(f.query, regulators);
  });

  test('no query keeps the default view', () {
    final f = exploreEquipmentFilter(null);
    expect(f.status, isNull);
    expect(f.allStatuses, isFalse);
    expect(f.query, isNull);
  });

  // The default view hides retired and sold gear (#636), so a status the
  // query decides on its own reads every status instead (#2590): otherwise
  // "retired or sold gear" found nothing and "gear that is not active" lost
  // its retired and sold items.
  test('a negated status stays in the query over every status', () {
    final not = NotNode(status('retired'));
    final f = exploreEquipmentFilter(not);
    expect(f.status, isNull);
    expect(f.allStatuses, isTrue);
    expect(f.query, not);
  });

  test('several statuses stay in the query over every status', () {
    final two = ConditionNode(
      FieldPath(const ['status']),
      QueryOp.inList,
      ListValue(const [EnumValue('retired'), EnumValue('sold')]),
    );
    final f = exploreEquipmentFilter(AndNode([regulators, two]));
    expect(f.status, isNull);
    expect(f.allStatuses, isTrue);
    expect(f.query, AndNode([regulators, two]));
  });

  test('a status inside an Or reads every status', () {
    final either = OrNode([status('retired'), regulators]);
    final f = exploreEquipmentFilter(either);
    expect(f.status, isNull);
    expect(f.allStatuses, isTrue);
    expect(f.query, either);
  });
}
