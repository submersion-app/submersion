import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/courses/data/services/course_edit_save_service.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/presentation/pages/course_detail_page.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The course the page shows, as stored: Rescue, PADI, in progress, at the
/// Reef shop, with no instructor and no notes.
final rescue = Course(
  id: 'k1',
  diverId: 'd1',
  name: 'Rescue',
  agency: 'padi',
  startDate: DateTime(2026, 3, 1),
  location: 'Reef',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Records each save the page asks for, stores its result where the page
/// reads the course from, and can fail.
class FakeCourseSave implements CourseEditSaveService {
  FakeCourseSave(this.stored);

  final StateController<Course?> stored;

  final calls = <({Course after, Set<String> cards})>[];
  bool fail = false;

  /// Whether to run the held writes a save is given, as the real one does
  /// inside its transaction.
  bool runHeld = true;

  /// Holds the write until completed.
  Completer<void>? gate;

  @override
  Future<({Course before, Course after})?> save({
    required String courseId,
    required Course Function(Course stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) async {
    if (fail) throw StateError('the save failed');
    await gate?.future;
    final before = stored.state!;
    final after = apply(before);
    calls.add((after: after, cards: changedCardIds.toSet()));
    if (runHeld) await alsoWrite?.call();
    stored.state = after;
    return (before: before, after: after);
  }

  /// Each new course the page asked to create, failed ones included.
  final creates = <({Course course, Set<String> cards})>[];

  @override
  Future<Course> create({
    required Course course,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) async {
    creates.add((course: course, cards: changedCardIds.toSet()));
    if (fail) throw StateError('the create failed');
    if (runHeld) await alsoWrite?.call();
    return course;
  }
}

class CoursePageHarness {
  CoursePageHarness(this.save, this.stored);

  final FakeCourseSave save;
  final StateController<Course?> stored;
}

final _storedProvider = StateProvider<Course?>((ref) => rescue);

/// Pumps the course page, at phone width, or as the list's pane when
/// [embedded]. [progress], [certifications] and [buddies] stand in for what
/// the page reads besides the course.
Future<CoursePageHarness> pumpCoursePage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Course? course,
  bool openUnlocked = false,
  bool embedded = false,
  Size size = const Size(600, 1600),
  VoidCallback? onSittingEnded,
  VoidCallback? onDeleted,
  CourseProgress? progress,
  List<Certification> certifications = const [],
  bool certificationsFail = false,
  List<Buddy> buddies = const [],
  List<Object> extraOverrides = const [],
}) async {
  final shown = course ?? rescue;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  late CoursePageHarness harness;
  final page = CourseDetailPage(
    courseId: shown.id,
    openUnlocked: openUnlocked,
    embedded: embedded,
    onSittingEnded: onSittingEnded,
    onDeleted: onDeleted,
  );
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...overrides,
        _storedProvider.overrideWith((ref) => shown),
        courseByIdProvider(
          shown.id,
        ).overrideWith((ref) async => ref.watch(_storedProvider)),
        courseDivesProvider(shown.id).overrideWith((ref) async => const []),
        certificationsForCourseProvider(shown.id).overrideWith(
          (ref) async => certificationsFail
              ? throw StateError('the read failed')
              : certifications,
        ),
        courseProgressProvider(shown.id).overrideWith(
          (ref) async =>
              progress ??
              CourseProgress(courseId: shown.id, requirements: const []),
        ),
        suggestedDivesProvider(shown.id).overrideWith((ref) async => const []),
        for (final buddy in buddies)
          buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
        courseEditSaveServiceProvider.overrideWith((ref) {
          final save = FakeCourseSave(ref.watch(_storedProvider.notifier));
          harness = CoursePageHarness(
            save,
            ref.watch(_storedProvider.notifier),
          );
          return save;
        }),
        ...extraOverrides,
      ],
      child: Theme(
        data: AppThemeRegistry.resolveTheme(
          AppThemeRegistry.presets.first,
          brightness,
        ),
        child: embedded ? Scaffold(body: page) : page,
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CourseDetailPage)),
  );
  container.read(courseEditSaveServiceProvider);
  return harness;
}

/// What a test of a new course's page pumped: the fake save, and how the
/// page ended.
class NewCourseHarness {
  late FakeCourseSave save;
  Object? popped;
  bool poppedAtAll = false;
  final createdIds = <String>[];
}

/// Pumps a new course's page (issue #4527, phase 3, plan 11): a full page
/// pushed over a launcher, or the pane's ([embedded]). Needs the test
/// database: the cards read nothing for an id not stored.
Future<NewCourseHarness> pumpNewCoursePage(
  WidgetTester tester, {
  bool embedded = false,
  Brightness brightness = Brightness.light,
  Size size = const Size(600, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final harness = NewCourseHarness();
  final page = CourseDetailPage.newCourse(
    embedded: embedded,
    onCreated: harness.createdIds.add,
  );
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...overrides,
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        courseEditSaveServiceProvider.overrideWith(
          (ref) => harness.save = FakeCourseSave(
            ref.watch(_storedProvider.notifier),
          ),
        ),
      ],
      child: Theme(
        data: AppThemeRegistry.resolveTheme(
          AppThemeRegistry.presets.first,
          brightness,
        ),
        child: embedded
            ? Scaffold(body: page)
            : Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      final result = await Navigator.of(
                        context,
                      ).push(MaterialPageRoute<Object?>(builder: (_) => page));
                      harness
                        ..poppedAtAll = true
                        ..popped = result;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
      ),
    ),
  );
  if (!embedded) await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  ProviderScope.containerOf(
    tester.element(find.byType(CourseDetailPage)),
  ).read(courseEditSaveServiceProvider);
  return harness;
}
