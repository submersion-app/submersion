import 'package:submersion/core/constants/certification_enums.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/editing/course_card_ids.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';

const _log = LoggerService('CourseNewSitting');

/// A new course's sitting (issue #4527, phase 3, plan 11): its seed and
/// the cards laid out open.

/// A new course's starting record under [id]: the active diver's, of PADI,
/// starting today, as the form starts one. A diver that cannot be read
/// leaves none, for Save to take the one active then.
Future<Course> newCourseSeed(RecordSeedRead read, {required String id}) async {
  String? diverId;
  try {
    diverId = await read(validatedCurrentDiverIdProvider.future);
  } catch (error, stackTrace) {
    _log.warning(
      'Could not read the diver for a new course',
      error: error,
      stackTrace: stackTrace,
    );
  }
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
