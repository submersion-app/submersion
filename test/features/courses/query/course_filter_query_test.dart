import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/courses/domain/models/course_filter_state.dart';
import 'package:submersion/features/courses/query/course_filter_query.dart';

void main() {
  final padi = ConditionNode(
    FieldPath(['agency']),
    QueryOp.eq,
    const EnumValue('padi'),
  );
  final open = ConditionNode(
    FieldPath(['completionDate']),
    QueryOp.isEmpty,
    null,
  );
  final done = ConditionNode(
    FieldPath(['completionDate']),
    QueryOp.isSet,
    null,
  );

  test('status lowers to completionDate; the query ANDs on', () {
    expect(const CourseFilterState().toQuery(), isNull);
    expect(
      const CourseFilterState(status: CourseStatusFilter.inProgress).toQuery(),
      open,
    );
    expect(
      const CourseFilterState(status: CourseStatusFilter.completed).toQuery(),
      done,
    );
    expect(CourseFilterState(query: padi).toQuery(), padi);
    expect(
      CourseFilterState(
        status: CourseStatusFilter.completed,
        query: padi,
      ).toQuery(),
      AndNode([done, padi]),
    );
  });

  test('filter states compare by value', () {
    expect(CourseFilterState(query: padi), CourseFilterState(query: padi));
    expect(
      const CourseFilterState(
        status: CourseStatusFilter.completed,
      ).copyWith(clearQuery: true).hasActiveFilters,
      isTrue,
    );
    expect(const CourseFilterState().hasActiveFilters, isFalse);
  });
}
