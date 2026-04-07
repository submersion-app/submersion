import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/pages/course_list_page.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void _setMobileTestSurfaceSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _MockCourseListNotifier extends StateNotifier<AsyncValue<List<Course>>>
    implements CourseListNotifier {
  _MockCourseListNotifier(AsyncValue<List<Course>> state) : super(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<List<Override>> _buildOverrides({
  List<Course> courses = const [],
  bool loading = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    courseListNotifierProvider.overrideWith(
      (ref) => _MockCourseListNotifier(
        loading ? const AsyncValue.loading() : AsyncValue.data(courses),
      ),
    ),
    courseListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
  ];
}

void main() {
  group('CourseListPage', () {
    testWidgets('shows Training Courses title in app bar', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CourseListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Training Courses'), findsOneWidget);
    });

    testWidgets('shows Add Course FAB', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CourseListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add Course'), findsOneWidget);
    });

    testWidgets('shows empty state when no courses', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CourseListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No training courses yet'), findsOneWidget);
    });

    testWidgets('shows loading indicator while loading', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildOverrides(loading: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CourseListPage(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows course names when data loaded', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final now = DateTime.now();
      final testCourses = [
        Course(
          id: '1',
          diverId: 'diver-1',
          name: 'Advanced Open Water',
          agency: CertificationAgency.padi,
          startDate: DateTime(2024, 1, 10),
          notes: '',
          createdAt: now,
          updatedAt: now,
        ),
        Course(
          id: '2',
          diverId: 'diver-1',
          name: 'Rescue Diver',
          agency: CertificationAgency.ssi,
          startDate: DateTime(2024, 3, 5),
          notes: '',
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final overrides = await _buildOverrides(courses: testCourses);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CourseListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Advanced Open Water'), findsOneWidget);
      expect(find.text('Rescue Diver'), findsOneWidget);
    });
  });
}
