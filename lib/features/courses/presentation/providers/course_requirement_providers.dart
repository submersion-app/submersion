import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

/// Repository provider
final courseRequirementRepositoryProvider =
    Provider<CourseRequirementRepository>((ref) {
      return CourseRequirementRepository();
    });

/// Requirement progress for one course. Self-invalidates on any write to
/// the requirement tables (including sync merges) and on any dive write:
/// getCourseProgress joins dives/dive_sites for the linked-dive summaries
/// (number, date, site name), so editing a credited dive must refresh the
/// course detail page even when no requirement/link changed.
final courseProgressProvider = FutureProvider.family<CourseProgress, String>((
  ref,
  courseId,
) async {
  final repository = ref.watch(courseRequirementRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchRequirementsChanges());
  ref.invalidateSelfWhen(ref.watch(diveRepositoryProvider).watchDivesChanges());
  return repository.getCourseProgress(courseId);
});

/// Candidate dives to credit toward requirements of a course. Watches both
/// the requirement tables (links consume suggestions) and the dives table
/// (new logged dives appear as candidates -- issue #217 lesson).
final suggestedDivesProvider =
    FutureProvider.family<List<RequirementDiveSummary>, String>((
      ref,
      courseId,
    ) async {
      final repository = ref.watch(courseRequirementRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchRequirementsChanges());
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDivesChanges(),
      );
      return repository.getSuggestedDives(courseId);
    });

/// One in-progress course with its requirement progress.
typedef ActiveCourseProgress = ({Course course, CourseProgress progress});

/// All in-progress courses of the current diver with their progress, for
/// the dashboard card. Courses without requirements are included; the card
/// filters totalCount == 0 (nothing meaningful to show).
final activeCoursesProgressProvider =
    FutureProvider<List<ActiveCourseProgress>>((ref) async {
      final courses = await ref.watch(inProgressCoursesProvider.future);
      final repository = ref.watch(courseRequirementRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchRequirementsChanges());
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDivesChanges(),
      );
      final progresses = await Future.wait(
        courses.map((course) => repository.getCourseProgress(course.id)),
      );
      return [
        for (var i = 0; i < courses.length; i++)
          (course: courses[i], progress: progresses[i]),
      ];
    });
