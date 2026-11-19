import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/courses/presentation/pages/course_detail_page.dart';
import 'package:submersion/features/courses/presentation/pages/course_edit_page.dart';
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
