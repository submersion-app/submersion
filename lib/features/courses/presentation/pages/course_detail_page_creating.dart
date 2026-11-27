part of 'course_detail_page.dart';

/// A new course on the course page (issue #4527, phase 3, plan 11): the
/// page's hooks for the shared [RecordCreating]. It opens unlocked on a
/// seed ([newCourseSeed]) with Status, Details and Instructor laid out
/// open, and at Save creates the course and its earned certifications in
/// one transaction. It leaves with the new id, where the form went to the
/// course and threw away the stack under it (a dive's sitting included).
mixin _CourseDetailPageCreating
    on
        ConsumerState<CourseDetailPage>,
        RecordEditHost<CourseDetailPage, Course>,
        RecordCreating<CourseDetailPage, Course> {
  @override
  bool get isCreating => widget.newCourse;

  @override
  Future<Course?> makeNewRecordSeed(RecordSeedRead read, String id) =>
      newCourseSeed(read, id: id);

  @override
  List<String> newRecordLaidOut(Course seed) => newCourseLaidOut;

  /// The course and its held writes, in one transaction. A seed made with
  /// no diver takes the one active now, as the form does.
  @override
  Future<Course> createRecord(EditSession<Course> session) async {
    // Read before the first wait: the page can be gone by the end.
    final service = ref.read(courseEditSaveServiceProvider);
    var course = session.applyTo(session.stored);
    if (course.diverId.isEmpty) {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (diverId == null) throw StateError('No active diver');
      course = course.copyWith(diverId: diverId);
    }
    return service.create(
      course: course,
      changedCardIds: session.changedCardIds,
      alsoWrite: heldWritesForCreate(session),
    );
  }

  /// The course list read again, as the form's add does.
  @override
  Future<void> Function(Course created) captureAfterRecordCreated() {
    final list = ref.read(courseListNotifierProvider.notifier);
    return (_) => list.refresh();
  }

  @override
  String newRecordTitle(BuildContext context) => context.l10n.courses_title_new;

  @override
  String get newRecordLeaveLocation => '/courses';

  @override
  bool get newRecordEmbedded => widget.embedded;

  @override
  void Function(String id)? get onNewRecordCreated => widget.onCreated;

  @override
  VoidCallback? get onNewRecordCancelled => widget.onCreateCancelled;

  @override
  ({String title, String body}) newRecordUnavailable(
    BuildContext context, {
    Object? error,
  }) => (
    title: context.l10n.courses_title_new,
    body: '${context.l10n.common_label_error}: $error',
  );
}
