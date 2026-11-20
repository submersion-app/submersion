import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/courses/presentation/pages/course_detail_page.dart';
import 'package:submersion/features/courses/presentation/pages/course_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';
import 'package:submersion/shared/widgets/record_editing/unlock_record_editing_flag.dart';

/// Where the old course edit address (`/courses/<id>/edit`) goes (issue
/// #4527, phase 3): with [unlockEditing], the course page opened unlocked;
/// null, keeping the edit form, otherwise.
String? courseEditLocation(
  String courseId, {
  bool unlockEditing = kUnlockRecordEditing,
}) => unlockEditing ? '/courses/$courseId?mode=edit' : null;

/// The edit route's redirect: [courseEditLocation] for its address.
String? courseEditRedirect(BuildContext context, GoRouterState state) =>
    courseEditLocation(state.pathParameters['courseId']!);

/// The courses list's edit pane, as the master-detail scaffold's and table
/// mode's `editBuilder`: with [unlockEditing], the course page opened
/// unlocked, back to the course in view mode ([onCancel]) once its sitting
/// ends; else the edit form as before.
Widget courseEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (unlockEditing) {
    return CourseDetailPage(
      courseId: id,
      embedded: true,
      unlockEditing: unlockEditing,
      openUnlocked: true,
      onSittingEnded: onCancel,
      // A delete from the pane returns it to the list, as from view mode.
      onDeleted: onDeleted,
    );
  }
  return CourseEditPage(
    courseId: id,
    embedded: true,
    onSaved: () => onSaved(id),
    onCancel: onCancel,
  );
}

/// The new-course address (`/courses/new`; issue #4527, phase 3, plan 11):
/// with [unlockEditing], the course page opened unlocked on a new course,
/// which pops its id; else the form, as before.
Widget newCoursePage({bool unlockEditing = kUnlockRecordEditing}) =>
    unlockEditing ? const CourseDetailPage.newCourse() : const CourseEditPage();

/// The course list's new-course pane (`?mode=new`), as the master-detail
/// scaffold's `createBuilder`: with [unlockEditing], the course page on a
/// new course, whose created id is handed to [onSaved]; else the form.
Widget newCoursePane(
  BuildContext context,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (unlockEditing) {
    return CourseDetailPage.newCourse(
      embedded: true,
      onCreated: onSaved,
      onCreateCancelled: onCancel,
    );
  }
  return CourseEditPage(
    embedded: true,
    onSavedWithId: onSaved,
    onCancel: onCancel,
  );
}

/// Opens a new course from the course list on a phone or its empty state:
/// with [unlockEditing], the course opens, locked, once created, as a new
/// site does (plan 11, Question 3); else the form, as before.
Future<void> openNewCourse(
  BuildContext context, {
  bool unlockEditing = kUnlockRecordEditing,
}) {
  return openNewRecord(
    context,
    newLocation: '/courses/new',
    recordLocation: (id) => '/courses/$id',
    openCreated: unlockEditing,
  );
}
