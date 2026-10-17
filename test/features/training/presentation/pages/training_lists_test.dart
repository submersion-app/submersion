import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/training_locations.dart';
import 'package:submersion/features/certifications/domain/constants/certification_field.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_detail_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_summary_widget.dart';
import 'package:submersion/features/courses/domain/constants/course_field.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/pages/course_detail_page.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/training/presentation/pages/training_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';

class _MockCertificationListNotifier
    extends StateNotifier<AsyncValue<List<Certification>>>
    implements CertificationListNotifier {
  _MockCertificationListNotifier()
    : super(const AsyncValue.data(<Certification>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockCourseListNotifier extends StateNotifier<AsyncValue<List<Course>>>
    implements CourseListNotifier {
  _MockCourseListNotifier() : super(const AsyncValue.data(<Course>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _CertificationTableConfig
    extends EntityTableConfigNotifier<CertificationField> {
  _CertificationTableConfig()
    : super(
        defaultConfig: EntityTableViewConfig<CertificationField>(
          columns: [
            EntityTableColumnConfig(
              field: CertificationField.certName,
              isPinned: true,
            ),
          ],
        ),
        fieldFromName: CertificationFieldAdapter.instance.fieldFromName,
      );
}

class _CourseTableConfig extends EntityTableConfigNotifier<CourseField> {
  _CourseTableConfig()
    : super(
        defaultConfig: EntityTableViewConfig<CourseField>(
          columns: [
            EntityTableColumnConfig(
              field: CourseField.courseName,
              isPinned: true,
            ),
          ],
        ),
        fieldFromName: CourseFieldAdapter.instance.fieldFromName,
      );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<GoRouter> pumpTraining(
    WidgetTester tester, {
    required String initialLocation,
    required Size size,
    ListViewMode viewMode = ListViewMode.detailed,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        for (final tab in TrainingTab.values)
          GoRoute(
            path: tab.path,
            pageBuilder: (_, _) => trainingHostPage(TrainingPage(tab: tab)),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          certificationListNotifierProvider.overrideWith(
            (ref) => _MockCertificationListNotifier(),
          ),
          courseListNotifierProvider.overrideWith(
            (ref) => _MockCourseListNotifier(),
          ),
          certificationListViewModeProvider.overrideWith((ref) => viewMode),
          courseListViewModeProvider.overrideWith((ref) => viewMode),
          certificationTableConfigProvider.overrideWith(
            (ref) => _CertificationTableConfig(),
          ),
          courseTableConfigProvider.overrideWith((ref) => _CourseTableConfig()),
          courseByIdProvider.overrideWith((ref, id) async => null),
          courseDivesProvider.overrideWith((ref, id) async => const []),
          certificationsForCourseProvider.overrideWith(
            (ref, id) async => const [],
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  final toggle = find.byKey(const ValueKey('training_section_toggle'));

  for (final (name, size, mode) in const [
    ('phone', Size(400, 800), ListViewMode.detailed),
    ('desktop', Size(1200, 800), ListViewMode.detailed),
    ('table mode', Size(1200, 800), ListViewMode.table),
  ]) {
    testWidgets('$name: the real Certifications list carries the switch', (
      tester,
    ) async {
      // Both list contents are long-standing 400px-wide layouts that overflow
      // under the test font; that is not what this checks.
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);

      await pumpTraining(
        tester,
        initialLocation: '/certifications',
        size: size,
        viewMode: mode,
      );

      expect(toggle, findsOneWidget);
    });
  }

  testWidgets('desktop: a link straight to a course opens the Courses tab on '
      'it, and Certifications opens on its own summary', (tester) async {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);

    final router = await pumpTraining(
      tester,
      initialLocation: '/courses?selected=c1',
      size: const Size(1200, 800),
    );

    final detail = tester.widget<CourseDetailPage>(
      find.byType(CourseDetailPage),
    );
    expect(detail.courseId, 'c1');
    expect(find.byType(CertificationDetailPage), findsNothing);

    await tester.tap(find.text('Certifications').first);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/certifications',
    );
    expect(find.byType(CertificationSummaryWidget), findsOneWidget);
    expect(find.byType(CertificationDetailPage), findsNothing);
  });
}
