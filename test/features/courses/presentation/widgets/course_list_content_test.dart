import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/domain/constants/course_field.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/course_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestCourseTableConfigNotifier
    extends EntityTableConfigNotifier<CourseField> {
  _TestCourseTableConfigNotifier(EntityTableViewConfig<CourseField> config)
    : super(
        defaultConfig: config,
        fieldFromName: CourseFieldAdapter.instance.fieldFromName,
      );
}

class _MockCourseListNotifier extends StateNotifier<AsyncValue<List<Course>>>
    implements CourseListNotifier {
  _MockCourseListNotifier(List<Course> courses)
    : super(AsyncValue.data(courses));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _testConfig = EntityTableViewConfig<CourseField>(
  columns: [
    EntityTableColumnConfig(field: CourseField.courseName, isPinned: true),
    EntityTableColumnConfig(field: CourseField.agency),
    EntityTableColumnConfig(field: CourseField.startDate),
    EntityTableColumnConfig(field: CourseField.completionDate),
    EntityTableColumnConfig(field: CourseField.isCompleted),
    EntityTableColumnConfig(field: CourseField.location),
  ],
);

final _now = DateTime.now();

Course _makeCourse({
  required String id,
  required String name,
  CertificationAgency agency = CertificationAgency.padi,
  DateTime? startDate,
  DateTime? completionDate,
  String? location,
}) {
  return Course(
    id: id,
    diverId: 'diver-1',
    name: name,
    agency: agency,
    startDate: startDate ?? DateTime(2024, 1, 10),
    completionDate: completionDate,
    location: location,
    createdAt: _now,
    updatedAt: _now,
  );
}

Future<List<Override>> _buildOverrides({required List<Course> courses}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    courseListNotifierProvider.overrideWith(
      (ref) => _MockCourseListNotifier(courses),
    ),
    courseListViewModeProvider.overrideWith((ref) => ListViewMode.table),
    courseTableConfigProvider.overrideWith(
      (ref) => _TestCourseTableConfigNotifier(_testConfig),
    ),
  ];
}

void main() {
  group('CourseListContent in table mode', () {
    testWidgets('renders table with column headers', (tester) async {
      final courses = [
        _makeCourse(
          id: 'co1',
          name: 'Advanced Open Water',
          agency: CertificationAgency.padi,
          startDate: DateTime(2024, 1, 10),
          completionDate: DateTime(2024, 1, 15),
          location: 'Koh Tao',
        ),
        _makeCourse(
          id: 'co2',
          name: 'Rescue Diver',
          agency: CertificationAgency.ssi,
          startDate: DateTime(2024, 3, 5),
        ),
      ];

      final overrides = await _buildOverrides(courses: courses);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Verify column headers from shortLabel values
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Agency'), findsOneWidget);
      expect(find.text('Started'), findsOneWidget);
    });

    testWidgets('renders rows for each course', (tester) async {
      final courses = [
        _makeCourse(id: 'co1', name: 'Open Water Diver'),
        _makeCourse(id: 'co2', name: 'Advanced Open Water'),
        _makeCourse(id: 'co3', name: 'Rescue Diver'),
      ];

      final overrides = await _buildOverrides(courses: courses);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Open Water Diver'), findsOneWidget);
      expect(find.text('Advanced Open Water'), findsOneWidget);
      expect(find.text('Rescue Diver'), findsOneWidget);
    });

    testWidgets('shows empty state when no courses', (tester) async {
      final overrides = await _buildOverrides(courses: []);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
    });

    testWidgets('table app bar includes column settings button', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        courses: [_makeCourse(id: 'co1', name: 'Nitrox')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.view_column_outlined), findsOneWidget);
    });

    testWidgets('renders with showAppBar false (compact bar)', (tester) async {
      final overrides = await _buildOverrides(
        courses: [_makeCourse(id: 'co1', name: 'Deep Diver')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.text('Deep Diver'), findsOneWidget);
    });

    testWidgets('table app bar has more options popup', (tester) async {
      final overrides = await _buildOverrides(
        courses: [_makeCourse(id: 'co1', name: 'Nitrox')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('table app bar popup menu shows view mode items', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        courses: [_makeCourse(id: 'co1', name: 'Nitrox')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Detailed'), findsOneWidget);
    });

    testWidgets('table app bar has vertical divider', (tester) async {
      final overrides = await _buildOverrides(
        courses: [_makeCourse(id: 'co1', name: 'Nitrox')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    testWidgets('compact bar in table mode has column settings button', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        courses: [_makeCourse(id: 'co1', name: 'Deep Diver')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.view_column_outlined), findsOneWidget);
    });

    testWidgets('compact bar in table mode has popup menu', (tester) async {
      final overrides = await _buildOverrides(
        courses: [_makeCourse(id: 'co1', name: 'Deep Diver')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('table renders course data in cells', (tester) async {
      final courses = [
        _makeCourse(
          id: 'co1',
          name: 'Advanced Open Water',
          agency: CertificationAgency.padi,
          startDate: DateTime(2024, 1, 10),
          completionDate: DateTime(2024, 1, 15),
          location: 'Koh Tao',
        ),
      ];

      final overrides = await _buildOverrides(courses: courses);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Advanced Open Water'), findsOneWidget);
    });

    testWidgets('renders completed and in-progress courses', (tester) async {
      final courses = [
        _makeCourse(
          id: 'ip1',
          name: 'Intro to Cave',
          startDate: DateTime(2024, 2, 1),
          completionDate: null,
        ),
        _makeCourse(
          id: 'cp1',
          name: 'Full Cave',
          startDate: DateTime(2024, 3, 1),
          completionDate: DateTime(2024, 3, 15),
        ),
      ];

      final overrides = await _buildOverrides(courses: courses);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Intro to Cave'), findsOneWidget);
      expect(find.text('Full Cave'), findsOneWidget);
    });

    testWidgets('renders with location data', (tester) async {
      final courses = [
        _makeCourse(id: 'loc1', name: 'Tech Diving', location: 'Dahab, Egypt'),
      ];

      final overrides = await _buildOverrides(courses: courses);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Tech Diving'), findsOneWidget);
    });

    testWidgets('renders many courses without crash', (tester) async {
      final courses = List.generate(
        15,
        (i) => _makeCourse(id: 'mc$i', name: 'Course $i'),
      );

      final overrides = await _buildOverrides(courses: courses);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Course 0'), findsOneWidget);
    });

    testWidgets('tapping popup menu Detailed switches from table mode', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        courses: [_makeCourse(id: 'co1', name: 'Test Course')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detailed'));
      await tester.pumpAndSettle();

      // View mode was changed from table
      expect(find.byIcon(Icons.view_column_outlined), findsNothing);
    });

    testWidgets('compact bar column settings opens picker in table mode', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        courses: [_makeCourse(id: 'co1', name: 'Test Course')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.view_column_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Columns'), findsOneWidget);
    });

    testWidgets('compact bar popup menu Detailed switches view mode', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        courses: [_makeCourse(id: 'co1', name: 'Test Course')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detailed'));
      await tester.pumpAndSettle();

      // View mode was changed from table
      expect(find.byIcon(Icons.view_column_outlined), findsNothing);
    });
  });
}
