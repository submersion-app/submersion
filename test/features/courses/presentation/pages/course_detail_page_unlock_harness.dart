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
}

class CoursePageHarness {
  CoursePageHarness(this.save, this.stored);

  final FakeCourseSave save;
  final StateController<Course?> stored;
}

final _storedProvider = StateProvider<Course?>((ref) => rescue);

/// Pumps the course page with the phase 3 switch on (unless
/// [unlockEditing] is false), at phone width, or as the list's pane when
/// [embedded]. [progress], [certifications] and [buddies] stand in for what
/// the page reads besides the course.
Future<CoursePageHarness> pumpCoursePage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Course? course,
  bool unlockEditing = true,
  bool openUnlocked = false,
  bool embedded = false,
  Size size = const Size(600, 1600),
  VoidCallback? onSittingEnded,
  VoidCallback? onDeleted,
  CourseProgress? progress,
  List<Certification> certifications = const [],
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
    unlockEditing: unlockEditing,
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
        certificationsForCourseProvider(
          shown.id,
        ).overrideWith((ref) async => certifications),
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
