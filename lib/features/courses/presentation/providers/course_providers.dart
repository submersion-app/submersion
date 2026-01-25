import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Repository provider
final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return CourseRepository();
});

/// All courses provider
final allCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final repository = ref.watch(courseRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getAllCourses(diverId: validatedDiverId);
});

/// In-progress courses provider (courses without completion date)
final inProgressCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final repository = ref.watch(courseRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getInProgressCourses(diverId: validatedDiverId);
});

/// Completed courses provider
final completedCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final repository = ref.watch(courseRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getCompletedCourses(diverId: validatedDiverId);
});

/// Sort state for course list
final courseSortProvider = StateProvider<SortState<CourseSortField>>(
  (ref) => const SortState(
    field: CourseSortField.startDate,
    direction: SortDirection.descending,
  ),
);

/// Apply sorting to a list of courses
List<Course> applyCourseSorting(
  List<Course> courses,
  SortState<CourseSortField> sort,
) {
  final sorted = List<Course>.from(courses);

  sorted.sort((a, b) {
    int comparison;
    // For text fields, invert direction (user expects descending = A->Z)
    final invertForText =
        sort.field == CourseSortField.name ||
        sort.field == CourseSortField.agency;

    switch (sort.field) {
      case CourseSortField.name:
        comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case CourseSortField.startDate:
        comparison = a.startDate.compareTo(b.startDate);
      case CourseSortField.agency:
        comparison = a.agency.displayName.compareTo(b.agency.displayName);
      case CourseSortField.status:
        // In progress first, then completed (by completion date)
        if (a.isInProgress && !b.isInProgress) {
          comparison = -1;
        } else if (!a.isInProgress && b.isInProgress) {
          comparison = 1;
        } else if (a.completionDate != null && b.completionDate != null) {
          comparison = a.completionDate!.compareTo(b.completionDate!);
        } else {
          comparison = a.startDate.compareTo(b.startDate);
        }
    }

    if (invertForText) {
      return sort.direction == SortDirection.ascending
          ? -comparison
          : comparison;
    }
    return sort.direction == SortDirection.ascending ? comparison : -comparison;
  });

  return sorted;
}

/// Single course by ID provider
final courseByIdProvider = FutureProvider.family<Course?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(courseRepositoryProvider);
  return repository.getCourseById(id);
});

/// Course for a specific dive
final courseForDiveProvider = FutureProvider.family<Course?, String>((
  ref,
  diveId,
) async {
  final repository = ref.watch(courseRepositoryProvider);
  return repository.getCourseForDive(diveId);
});

/// Course for a specific certification
final courseForCertificationProvider = FutureProvider.family<Course?, String>((
  ref,
  certificationId,
) async {
  final repository = ref.watch(courseRepositoryProvider);
  return repository.getCourseForCertification(certificationId);
});

/// Dives for a specific course
final courseDivesProvider = FutureProvider.family<List<Dive>, String>((
  ref,
  courseId,
) async {
  final diveRepository = ref.watch(diveRepositoryProvider);
  return diveRepository.getDivesForCourse(courseId);
});

/// Dive count for a course
final courseDiveCountProvider = FutureProvider.family<int, String>((
  ref,
  courseId,
) async {
  final repository = ref.watch(courseRepositoryProvider);
  return repository.getDiveCountForCourse(courseId);
});

/// Courses by agency
final coursesByAgencyProvider =
    FutureProvider.family<List<Course>, CertificationAgency>((
      ref,
      agency,
    ) async {
      final repository = ref.watch(courseRepositoryProvider);
      final validatedDiverId = await ref.watch(
        validatedCurrentDiverIdProvider.future,
      );
      return repository.getCoursesByAgency(agency, diverId: validatedDiverId);
    });

/// Course search provider
final courseSearchProvider = FutureProvider.family<List<Course>, String>((
  ref,
  query,
) async {
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  if (query.isEmpty) {
    return ref.watch(allCoursesProvider).value ?? [];
  }
  final repository = ref.watch(courseRepositoryProvider);
  return repository.searchCourses(query, diverId: validatedDiverId);
});

/// Course list notifier for mutations
class CourseListNotifier extends StateNotifier<AsyncValue<List<Course>>> {
  final CourseRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  CourseListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    _initializeAndLoad();

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        state = const AsyncValue.loading();
        _ref.invalidate(validatedCurrentDiverIdProvider);
        _ref.invalidate(allCoursesProvider);
        _ref.invalidate(inProgressCoursesProvider);
        _ref.invalidate(completedCoursesProvider);
        _initializeAndLoad();
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    state = const AsyncValue.loading();
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadCourses();
  }

  Future<void> _loadCourses() async {
    state = const AsyncValue.loading();
    try {
      final courses = await _repository.getAllCourses(
        diverId: _validatedDiverId,
      );
      state = AsyncValue.data(courses);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    // Get fresh validated diver ID before loading
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadCourses();
    _ref.invalidate(allCoursesProvider);
    _ref.invalidate(inProgressCoursesProvider);
    _ref.invalidate(completedCoursesProvider);
  }

  Future<Course> addCourse(Course course) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Always set diverId to the current validated diver for new items
    final courseWithDiver = validatedId != null
        ? course.copyWith(diverId: validatedId)
        : course;
    final newCourse = await _repository.createCourse(courseWithDiver);
    await refresh();
    return newCourse;
  }

  Future<void> updateCourse(Course course) async {
    await _repository.updateCourse(course);
    await refresh();
    _ref.invalidate(courseByIdProvider(course.id));
  }

  Future<void> deleteCourse(String id) async {
    await _repository.deleteCourse(id);
    await refresh();
  }

  Future<void> linkDiveToCourse(String diveId, String courseId) async {
    await _repository.linkDiveToCourse(diveId, courseId);
    _ref.invalidate(courseForDiveProvider(diveId));
    _ref.invalidate(courseDivesProvider(courseId));
    _ref.invalidate(courseDiveCountProvider(courseId));
  }

  Future<void> unlinkDiveFromCourse(String diveId, String courseId) async {
    await _repository.unlinkDiveFromCourse(diveId);
    _ref.invalidate(courseForDiveProvider(diveId));
    _ref.invalidate(courseDivesProvider(courseId));
    _ref.invalidate(courseDiveCountProvider(courseId));
  }

  Future<void> linkCourseToCertification(
    String courseId,
    String certificationId,
  ) async {
    await _repository.linkCourseToCertification(courseId, certificationId);
    _ref.invalidate(courseByIdProvider(courseId));
    _ref.invalidate(courseForCertificationProvider(certificationId));
    await refresh();
  }
}

final courseListNotifierProvider =
    StateNotifierProvider<CourseListNotifier, AsyncValue<List<Course>>>((ref) {
      final repository = ref.watch(courseRepositoryProvider);
      return CourseListNotifier(repository, ref);
    });

/// Count of in-progress courses (for badges)
final inProgressCourseCountProvider = FutureProvider<int>((ref) async {
  final courses = await ref.watch(inProgressCoursesProvider.future);
  return courses.length;
});
