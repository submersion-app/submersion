import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/courses/domain/models/course_filter_state.dart';

/// Lowers the course list's filter to the query tree (#2365). The ONLY
/// evaluator of a CourseFilterState: a field added to it and not named here
/// fails `course_filter_query_census_test`. A course is in progress while
/// it has no completion date, which is how the entity defines it.
extension CourseFilterQuery on CourseFilterState {
  QueryNode? toQuery() {
    final parts = <QueryNode>[
      if (status == CourseStatusFilter.inProgress)
        ConditionNode(FieldPath(['completionDate']), QueryOp.isEmpty, null),
      if (status == CourseStatusFilter.completed)
        ConditionNode(FieldPath(['completionDate']), QueryOp.isSet, null),
      ?query,
    ];
    if (parts.isEmpty) return null;
    return parts.length == 1 ? parts.first : AndNode(parts);
  }
}
