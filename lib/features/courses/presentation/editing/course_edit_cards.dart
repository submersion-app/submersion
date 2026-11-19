import 'package:submersion/features/buddies/presentation/editing/instructor_card_editor.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/editing/course_card_editors.dart';
import 'package:submersion/features/courses/presentation/editing/course_card_ids.dart';
import 'package:submersion/features/courses/presentation/editing/course_certifications_sitting.dart';
import 'package:submersion/features/courses/presentation/editing/course_edit_fields.dart';
import 'package:submersion/features/courses/presentation/widgets/course_requirements_section.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';

/// The course page's cards that can be edited in place (issue #4527, phase
/// 3), by card id, in page order.
final Map<CourseCardId, EditCard<Course>> courseEditCards = {
  CourseCardId.status: EditCard<Course>(
    id: CourseCardId.status.name,
    title: (context) => CourseCardId.status.localizedDisplayName(context.l10n),
    isEmpty: (_) => false,
    // A name, as the form's validator has it.
    isValid: (session) => courseNameValid(session.working.name),
    editorBuilder: (context, session) =>
        CourseStatusCardEditor(session: session),
  ),
  CourseCardId.details: EditCard<Course>(
    id: CourseCardId.details.name,
    title: (context) => CourseCardId.details.localizedDisplayName(context.l10n),
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        CourseDetailsCardEditor(session: session),
  ),
  CourseCardId.instructor: EditCard<Course>(
    id: CourseCardId.instructor.name,
    title: (context) =>
        CourseCardId.instructor.localizedDisplayName(context.l10n),
    isEmpty: (c) =>
        c.instructorId == null &&
        c.instructorName == null &&
        c.instructorNumber == null,
    editorBuilder: (context, session) => InstructorCardEditor<Course>(
      session: session,
      field: courseInstructorField,
      nameLabel: context.l10n.courses_field_instructorName,
      numberLabel: context.l10n.courses_field_instructorNumber,
      keyPrefix: 'course-edit',
    ),
  ),
  CourseCardId.earnedCertifications: EditCard<Course>(
    id: CourseCardId.earnedCertifications.name,
    title: (context) =>
        CourseCardId.earnedCertifications.localizedDisplayName(context.l10n),
    // Whether it has any is the sitting's list, which the page reads.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        CourseEarnedCertificationsEditor(session: session),
  ),
  CourseCardId.requirements: EditCard<Course>(
    id: CourseCardId.requirements.name,
    title: (context) =>
        CourseCardId.requirements.localizedDisplayName(context.l10n),
    // Always on the page: with none, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) => CourseRequirementsSection(
      courseId: session.stored.id,
      editing: session,
    ),
  ),
  CourseCardId.notes: EditCard<Course>(
    id: CourseCardId.notes.name,
    title: (context) => CourseCardId.notes.localizedDisplayName(context.l10n),
    isEmpty: (c) => c.notes.trim().isEmpty,
    editorBuilder: (context, session) =>
        CourseNotesCardEditor(session: session),
  ),
  CourseCardId.documents: EditCard<Course>(
    id: CourseCardId.documents.name,
    title: (context) =>
        CourseCardId.documents.localizedDisplayName(context.l10n),
    // Always on the page: with none, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) => DocumentsSection<Course>(
      owner: DocumentOwner(DocumentOwnerKind.course, session.stored.id),
      editing: session,
    ),
  ),
};

/// The cards the page leaves out while they are empty, offered in the
/// strip, in page order.
const List<CourseCardId> courseOptionalCards = [
  CourseCardId.instructor,
  CourseCardId.earnedCertifications,
  CourseCardId.notes,
];
