import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/courses/presentation/pages/course_detail_page.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';

/// Where the old course edit address (`/courses/<id>/edit`) goes (issue
/// #4527, phase 3): the course page opened unlocked.
String courseEditLocation(String courseId) => '/courses/$courseId?mode=edit';

/// The edit route's redirect: [courseEditLocation] for its address.
String? courseEditRedirect(BuildContext context, GoRouterState state) =>
    courseEditLocation(state.pathParameters['courseId']!);

/// The courses list's edit pane, as the master-detail scaffold's and table
/// mode's `editBuilder`: the course page opened unlocked, back to the
/// course in view mode ([onCancel]) once its sitting ends. [onSaved] is the
/// scaffold's, and unused: a sitting saves in place.
Widget courseEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
}) => CourseDetailPage(
  courseId: id,
  embedded: true,
  openUnlocked: true,
  onSittingEnded: onCancel,
  // A delete from the pane returns it to the list, as from view mode.
  onDeleted: onDeleted,
);

/// The new-course address (`/courses/new`; issue #4527, phase 3, plan 11):
/// the course page opened unlocked on a new course, which pops its id.
Widget newCoursePage() => const CourseDetailPage.newCourse();

/// The course list's new-course pane (`?mode=new`), as the master-detail
/// scaffold's `createBuilder`: the course page on a new course, whose
/// created id is handed to [onSaved].
Widget newCoursePane(
  BuildContext context,
  void Function(String savedId) onSaved,
  VoidCallback onCancel,
) => CourseDetailPage.newCourse(
  embedded: true,
  onCreated: onSaved,
  onCreateCancelled: onCancel,
);

/// Opens a new course from the course list on a phone or its empty state:
/// the course opens, locked, once created, as a new site does (plan 11,
/// Question 3).
Future<void> openNewCourse(BuildContext context) => openNewRecord(
  context,
  newLocation: '/courses/new',
  recordLocation: (id) => '/courses/$id',
);
