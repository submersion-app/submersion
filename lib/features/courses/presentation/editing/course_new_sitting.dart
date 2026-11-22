import 'package:submersion/core/constants/certification_enums.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/editing/course_card_ids.dart';
import 'package:submersion/features/divers/presentation/providers/new_record_diver.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';

/// A new course's sitting (issue #4527, phase 3, plan 11): its seed and
/// the cards laid out open.

/// A new course's starting record under [id]: the active diver's, of PADI,
/// starting today, as the form starts one. A diver that cannot be read
/// leaves none, for Save to take the one active then.
Future<Course> newCourseSeed(RecordSeedRead read, {required String id}) async {
  final diverId = await newRecordDiverId(read, record: 'course');
  final now = DateTime.now();
  return Course(
    id: id,
    diverId: diverId ?? '',
    name: '',
    agency: CertificationAgency.padi.name,
    startDate: now,
    createdAt: now,
    updatedAt: now,
  );
}

/// The cards a new course opens with: Status, Details and Instructor.
final List<String> newCourseLaidOut = List.unmodifiable([
  CourseCardId.status.name,
  CourseCardId.details.name,
  CourseCardId.instructor.name,
]);
