import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/query/presentation/providers/query_cache_awaits.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';

/// Repository provider
final courseRequirementRepositoryProvider =
    Provider<CourseRequirementRepository>((ref) {
      return CourseRequirementRepository();
    });

/// Requirement progress for one course, with live updates from the logbook
/// tables that supply credited dives and the course's derived counts.
final courseProgressProvider = FutureProvider.family<CourseProgress, String>((
  ref,
  courseId,
) async {
  final repository = ref.watch(courseRequirementRepositoryProvider);
  final runner = ref.watch(queryIdSetRunnerProvider);
  const creditTables = {'courses', 'dives', 'dive_sites'};
  ref.invalidateSelfWhen(repository.watchRequirementsChanges());
  ref.invalidateSelfWhen(runner.watchTables(creditTables));
  return repository.getCourseProgress(
    courseId,
    prepareQueries: (diverId, tables) async {
      final cte = await _prepareCourseQueries(ref, diverId, tables);
      final additionalTables = tables.difference(creditTables);
      if (additionalTables.isNotEmpty) {
        ref.invalidateSelfWhen(runner.watchTables(additionalTables));
      }
      return cte;
    },
  );
});

final courseRequirementAmountProvider = FutureProvider.autoDispose
    .family<int, CourseRequirement>(
      (ref, requirement) => ref
          .watch(courseRequirementRepositoryProvider)
          .getDerivedAmount(
            requirement,
            prepareQueries: (diverId, tables) =>
                _prepareCourseQueries(ref, diverId, tables),
          ),
    );

Future<QueryCte?> _prepareCourseQueries(
  Ref ref,
  String diverId,
  Set<String> tables,
) async {
  if (!tables.any(queryCacheTables.contains)) return null;
  final activeDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  if (diverId != activeDiverId) {
    return prepareQueryCachesFor(ref, diverId, tables);
  }
  await awaitQueryCachesIfRead(ref, tables);
  return null;
}

/// Candidate dives to credit toward requirements of a course. Watches the
/// requirement tables (links consume suggestions), the dives table (new logged
/// dives appear as candidates -- issue #217 lesson), the courses table (the
/// course dates decide which dives qualify and in what order), and the
/// dive-to-course links (a dive assigned to the course leads the list).
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
      final courseRepository = ref.watch(courseRepositoryProvider);
      ref.invalidateSelfWhen(courseRepository.watchCoursesChanges());
      ref.invalidateSelfWhen(courseRepository.watchCourseLinkChanges());
      return repository.getSuggestedDives(courseId);
    });

/// Every dive the diver could still credit to this course, for the dive
/// picker. Disposed with the picker, because nothing else reads the whole
/// logbook this way.
final creditableDivesProvider = FutureProvider.autoDispose
    .family<List<RequirementDiveSummary>, String>((ref, courseId) async {
      final repository = ref.watch(courseRequirementRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchRequirementsChanges());
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDivesChanges(),
      );
      return repository.getCreditableDives(courseId);
    });

/// One in-progress course with its requirement progress.
typedef ActiveCourseProgress = ({Course course, CourseProgress progress});

/// All in-progress courses of the current diver with their progress, for
/// the dashboard card. Courses without requirements are included; the card
/// filters totalCount == 0 (nothing meaningful to show).
final activeCoursesProgressProvider =
    FutureProvider<List<ActiveCourseProgress>>((ref) async {
      final courses = await ref.watch(inProgressCoursesProvider.future);
      final progresses = await Future.wait([
        for (final course in courses)
          ref.watch(courseProgressProvider(course.id).future),
      ]);
      return [
        for (var i = 0; i < courses.length; i++)
          (course: courses[i], progress: progresses[i]),
      ];
    });
