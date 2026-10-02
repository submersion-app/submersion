import 'package:flutter/foundation.dart';

import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;

/// The course list's status chips.
enum CourseStatusFilter { all, inProgress, completed }

/// The course list's filter (#2365): the status chips and the advanced
/// query, lowered together by `CourseFilterQuery.toQuery`.
@immutable
class CourseFilterState {
  const CourseFilterState({this.status = CourseStatusFilter.all, this.query});

  final CourseStatusFilter status;

  /// The advanced part: typed, built or applied from a saved query.
  final QueryNode? query;

  bool get hasActiveFilters =>
      status != CourseStatusFilter.all || query != null;

  CourseFilterState copyWith({
    CourseStatusFilter? status,
    QueryNode? query,
    bool clearQuery = false,
  }) => CourseFilterState(
    status: status ?? this.status,
    query: clearQuery ? null : (query ?? this.query),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseFilterState &&
          other.status == status &&
          other.query == query;

  @override
  int get hashCode => Object.hash(status, query);

  @override
  String toString() => 'CourseFilterState(status: $status, query: $query)';
}
