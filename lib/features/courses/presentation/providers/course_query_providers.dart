import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/models/course_filter_state.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/query/course_filter_query.dart';
import 'package:submersion/features/courses/query/course_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';

/// The course list's filter (#2365): the status chips and the query.
final courseFilterProvider = StateProvider<CourseFilterState>(
  (ref) => const CourseFilterState(),
);

/// The course list narrowed by the status chips and the query in SQL; the
/// list, compact pane and table all read this, so the chips now apply in
/// table mode too.
final filteredCoursesProvider = Provider<AsyncValue<List<Course>>>(
  (ref) => narrowByQuery(
    ref,
    ref.watch(courseListNotifierProvider),
    courseQueryEntity,
    ref.watch(courseFilterProvider).toQuery(),
    (c) => c.id,
  ),
);
