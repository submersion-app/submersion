import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/query/equipment_filter_query.dart';

/// A saved equipment query that names the status takes over the sheet's
/// status axis on load (#2989), so the default view is not ANDed into it.
void main() {
  ConditionNode cond(String key, QueryOp op, QueryValue? v) =>
      ConditionNode(FieldPath([key]), op, v);
  final bcd = cond('type', QueryOp.eq, const EnumValue('bcd'));

  test('a picked status, as Save stores it, constrains the status', () {
    for (final status in [EquipmentStatus.sold, EquipmentStatus.retired]) {
      final saved = EquipmentFilterState(status: status).toSavedQuery()!;
      expect(constrainsEquipmentStatus(saved), isTrue, reason: '$status');
    }
  });

  test('status or active anywhere at the root counts', () {
    expect(
      constrainsEquipmentStatus(
        AndNode([
          bcd,
          NotNode(OrNode([cond('active', QueryOp.eq, const BoolValue(false))])),
        ]),
      ),
      isTrue,
    );
  });

  test('other fields, scoped paths and free text do not', () {
    expect(constrainsEquipmentStatus(bcd), isFalse);
    expect(constrainsEquipmentStatus(TextNode(['sold'])), isFalse);
    expect(
      constrainsEquipmentStatus(
        ScopedNode(
          FieldPath(['dives']),
          cond('status', QueryOp.eq, const EnumValue('x')),
        ),
      ),
      isFalse,
    );
  });
}
