import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/domain/constants/course_field.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/course_card.dart';
import 'package:submersion/features/courses/presentation/widgets/course_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/shared/selection/select_items_menu_entries.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/courses/domain/models/course_filter_state.dart';
import 'package:submersion/features/courses/presentation/providers/course_query_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';
import 'package:submersion/features/query/presentation/widgets/query_chips_frame.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/bulk_delete_contract.dart';
import '../../../../helpers/select_items_menu.dart';
import '../../../../helpers/selection_contract.dart';

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

  /// Narrow the visible list, standing in for a filter change.
  void showOnly(List<Course> courses) {
    state = AsyncValue.data(courses);
  }

  /// Ids bulk delete actually asked to remove.
  final deleted = <String>[];

  @override
  Future<void> deleteCourse(String id) async => deleted.add(id);

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

Future<List<Override>> _buildPhoneOverrides({
  required List<Course> courses,
  ListViewMode viewMode = ListViewMode.detailed,
  String? highlightedCourseId,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    courseListNotifierProvider.overrideWith(
      (ref) => _MockCourseListNotifier(courses),
    ),
    courseListViewModeProvider.overrideWith((ref) => viewMode),
    courseTableConfigProvider.overrideWith(
      (ref) => _TestCourseTableConfigNotifier(_testConfig),
    ),
    highlightedCourseIdProvider.overrideWith((ref) => highlightedCourseId),
  ];
}

void main() {
  // The title's subtitle counts the list (#2669), in both the phone app bar
  // and the desktop pane header.
  group('entry count subtitle', () {
    for (final showAppBar in const [true, false]) {
      testWidgets('${showAppBar ? 'app bar' : 'compact bar'} counts the list', (
        tester,
      ) async {
        final overrides = await _buildPhoneOverrides(
          courses: [
            _makeCourse(id: 'c1', name: 'Rescue'),
            _makeCourse(id: 'c2', name: 'Deep'),
          ],
        );
        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: CourseListContent(showAppBar: showAppBar),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(FeatureAppBarTitle),
            matching: find.text('2 courses'),
          ),
          findsOneWidget,
        );
      });
    }
  });
  group('bulk delete', () {
    late _MockCourseListNotifier notifier;

    Future<Widget> host(List<dynamic> rows) async {
      notifier = _MockCourseListNotifier(rows.cast());
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      return testApp(
        locale: const Locale('en'),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          courseListNotifierProvider.overrideWith((ref) => notifier),
          courseListViewModeProvider.overrideWith(
            (ref) => ListViewMode.detailed,
          ),
          courseTableConfigProvider.overrideWith(
            (ref) => _TestCourseTableConfigNotifier(_testConfig),
          ),
          highlightedCourseIdProvider.overrideWith((ref) => null),
        ],
        child: const CourseListContent(showAppBar: true),
      );
    }

    testWidgets('deletes every checked row and reports the count', (
      tester,
    ) async {
      final widget = await host([
        _makeCourse(id: 'c1', name: 'Aaa Course'),
        _makeCourse(id: 'c2', name: 'Bbb Course'),
      ]);

      await verifyBulkDelete(
        tester,
        build: () => widget,
        selectMenu: overflowMenuButton,
        selectButton: find.byKey(selectItemsMenuKey),
        expectedDeletedCount: 2,
      );

      expect(notifier.deleted, ['c1', 'c2']);
      expect(find.text('2 deleted'), findsOneWidget);
    });

    testWidgets('cancelling deletes nothing and keeps the selection', (
      tester,
    ) async {
      final widget = await host([_makeCourse(id: 'c1', name: 'Aaa Course')]);

      await verifyBulkDeleteCancels(
        tester,
        build: () => widget,
        selectMenu: overflowMenuButton,
        selectButton: find.byKey(selectItemsMenuKey),
      );

      expect(notifier.deleted, isEmpty);
    });
  });

  group('selection contract', () {
    testWidgets('satisfies the shared selection contract', (tester) async {
      final all = <Course>[
        _makeCourse(id: 'c1', name: 'Aaa Course'),
        _makeCourse(id: 'c2', name: 'Bbb Course'),
        _makeCourse(id: 'c3', name: 'Ccc Course'),
      ];
      final notifier = _MockCourseListNotifier(all);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final overrides = <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        courseListNotifierProvider.overrideWith((ref) => notifier),
        courseListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
        courseTableConfigProvider.overrideWith(
          (ref) => _TestCourseTableConfigNotifier(_testConfig),
        ),
        highlightedCourseIdProvider.overrideWith((ref) => null),
      ];

      await verifySelectionContract(
        tester,
        build: () => testApp(
          overrides: overrides,
          locale: const Locale('en'),
          child: const CourseListContent(showAppBar: true),
        ),
        selectMenu: overflowMenuButton,
        selectButton: find.byKey(selectItemsMenuKey),
        rowRoot: find.byType(CourseCard).first,
        firstRow: find.text('Aaa Course'),
        applyFilter: (tester) async {
          notifier.showOnly([all.first]);
        },
        visibleAfterFilter: 1,
      );
    });
  });

  // "Select items" moved from a header icon into the overflow menu, first
  // in the list (issue #2775), in both the phone app bar and the pane header.
  group('overflow menu "Select items"', () {
    for (final showAppBar in const [true, false]) {
      testWidgets('${showAppBar ? 'app bar' : 'compact bar'} lists it first '
          'and it enters selection', (tester) async {
        final overrides = await _buildPhoneOverrides(
          courses: [_makeCourse(id: 'c1', name: 'Rescue')],
        );
        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            locale: const Locale('en'),
            child: CourseListContent(showAppBar: showAppBar),
          ),
        );
        await tester.pumpAndSettle();

        // The header shows no Select icon of its own.
        expect(find.byIcon(Icons.checklist), findsNothing);

        await tester.tap(overflowMenuButton);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(selectItemsMenuKey)).dy,
          lessThan(tester.getTopLeft(find.text('Detailed')).dy),
        );

        await tester.tap(find.byKey(selectItemsMenuKey));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('selection_exit')), findsOneWidget);
        expect(find.text('0 selected'), findsOneWidget);
      });
    }
  });

  group('CourseListContent in table mode', () {
    // Table mode owns no app bar (TableModeLayout does), so "Select items"
    // sits in the page header's overflow and reaches the rows through the
    // controller the page passes in (issue #2775). The list draws no Select
    // strip of its own, and the contextual bar opens above the table.
    testWidgets('draws no Select strip and opens the contextual bar when the '
        "page's controller enters selection", (tester) async {
      final controller = SelectionController();
      addTearDown(controller.dispose);
      final overrides = await _buildOverrides(
        courses: [_makeCourse(id: 'co1', name: 'Deep Diver')],
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          locale: const Locale('en'),
          child: CourseListContent(
            showAppBar: false,
            selectionController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exitButton = find.byKey(const ValueKey('selection_exit'));
      expect(find.byKey(selectItemsMenuKey), findsNothing);
      expect(find.byIcon(Icons.checklist), findsNothing);
      expect(exitButton, findsNothing);

      controller.enterExplicit();
      await tester.pumpAndSettle();

      expect(exitButton, findsOneWidget);
      expect(find.text('0 selected'), findsOneWidget);
    });

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

      // Verify column headers from displayName values
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Agency'), findsOneWidget);
      expect(find.text('Start Date'), findsOneWidget);
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

    // Column settings are now provided by TableModeLayout, not the content
    // widget. The compact bar provides view mode controls only.

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

    testWidgets('tapping a row sets highlighted course id', (tester) async {
      final courses = [
        _makeCourse(id: 'c1', name: 'Rescue Diver'),
        _makeCourse(id: 'c2', name: 'Nitrox'),
      ];

      final overrides = await _buildOverrides(courses: courses);

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const Scaffold(
                  body: CourseListContent(showAppBar: true),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap on a course row
      await tester.tap(find.text('Rescue Diver'));
      // Pump past the DoubleTapGestureRecognizer's 300ms timeout
      await tester.pump(const Duration(milliseconds: 350));

      // The tap should have set the highlighted course ID
      expect(container.read(highlightedCourseIdProvider), 'c1');
    });

    testWidgets('double-tapping a row navigates to course detail', (
      tester,
    ) async {
      final courses = [_makeCourse(id: 'c1', name: 'Rescue Diver')];

      final overrides = await _buildOverrides(courses: courses);

      String? pushedPath;
      final router = GoRouter(
        initialLocation: '/courses',
        routes: [
          GoRoute(
            path: '/courses',
            builder: (context, state) =>
                const Scaffold(body: CourseListContent(showAppBar: true)),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  pushedPath = state.uri.toString();
                  return const Scaffold(body: SizedBox());
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      // Double-tap on a course row
      await tester.tap(find.text('Rescue Diver'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Rescue Diver'));
      await tester.pumpAndSettle();

      expect(pushedPath, '/courses/c1');
    });
  });

  group('CourseListContent in phone mode', () {
    // The compact bar used to pair a Flexible title with a Spacer. Both carry
    // flex: 1, so the Spacer took exactly half the free space rather than the
    // remainder, and the unclaimed half fell after the last icon under the
    // default MainAxisAlignment.start. Courses shows it worst because it has
    // the fewest actions, hence the most free space to halve.
    testWidgets('compact bar keeps its actions hard right', (tester) async {
      final overrides = await _buildPhoneOverrides(
        courses: [_makeCourse(id: 'co1', name: 'Deep Diver')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CourseListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      final barRight = tester.getBottomRight(find.byType(CourseListContent)).dx;
      final lastActionRight = tester
          .getBottomRight(find.byType(PopupMenuButton<String>))
          .dx;

      // Only the bar's own 8px horizontal padding may remain. Before the fix
      // the Spacer's unclaimed half left a gap of well over a hundred pixels.
      expect(
        barRight - lastActionRight,
        lessThanOrEqualTo(8.0),
        reason: 'action row is left-shifted by unabsorbed free space',
      );
    });

    testWidgets(
      'phone view highlights course when highlightedCourseIdProvider is set',
      (tester) async {
        final courses = [
          _makeCourse(id: 'co1', name: 'Alpha Course'),
          _makeCourse(id: 'co2', name: 'Bravo Course'),
        ];

        final overrides = await _buildPhoneOverrides(
          courses: courses,
          highlightedCourseId: 'co2',
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const CourseListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        final tiles = tester
            .widgetList<CourseCard>(find.byType(CourseCard))
            .toList();
        final alpha = tiles.firstWhere((t) => t.course.id == 'co1');
        final bravo = tiles.firstWhere((t) => t.course.id == 'co2');

        expect(alpha.isSelected, isFalse);
        expect(bravo.isSelected, isTrue);
      },
    );
  });

  group('status chips and query (#2365)', () {
    Future<ProviderContainer> pump(
      WidgetTester tester, {
      required Set<String> ids,
      CourseFilterState filter = const CourseFilterState(),
      ListViewMode viewMode = ListViewMode.detailed,
      Duration idsDelay = Duration.zero,
    }) async {
      final overrides = await _buildPhoneOverrides(
        courses: [
          _makeCourse(id: 'k1', name: 'Open Water'),
          _makeCourse(id: 'k2', name: 'Rescue'),
        ],
        viewMode: viewMode,
      );
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            courseFilterProvider.overrideWith((ref) => filter),
            entityQueryIdsProvider.overrideWith(
              (ref, key) => Future.delayed(idsDelay, () => ids),
            ),
          ],
          child: const CourseListContent(showAppBar: true),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(CourseListContent)),
      );
    }

    testWidgets('a status chip writes the filter state', (tester) async {
      final c = await pump(tester, ids: const {});
      await tester.tap(find.widgetWithText(FilterChip, 'In Progress'));
      await tester.pumpAndSettle();
      expect(
        c.read(courseFilterProvider).status,
        CourseStatusFilter.inProgress,
      );
    });

    testWidgets('a status chip keeps the checks that stay on screen', (
      tester,
    ) async {
      // A real id set takes a query's time, so the list has a loading frame.
      final c = await pump(
        tester,
        ids: const {'k1', 'k2'},
        idsDelay: const Duration(milliseconds: 50),
      );
      await enterSelectionViaMenu(tester);
      await tester.tap(find.byKey(const ValueKey('selection_select_all')));
      await tester.pumpAndSettle();

      // The chip's id set loads first; the selection must survive that.
      await tester.tap(find.widgetWithText(FilterChip, 'In Progress'));
      // One frame at once, as the app draws it, before the query answers.
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        c.read(courseFilterProvider).status,
        CourseStatusFilter.inProgress,
      );
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('table mode reads the filtered courses', (tester) async {
      await pump(
        tester,
        ids: {'k2'},
        filter: const CourseFilterState(status: CourseStatusFilter.completed),
        viewMode: ListViewMode.table,
      );
      expect(find.text('Rescue'), findsWidgets);
      expect(find.text('Open Water'), findsNothing);
    });

    testWidgets('table mode shows the status chips and can reset them', (
      tester,
    ) async {
      final c = await pump(
        tester,
        ids: const {'k1', 'k2'},
        filter: const CourseFilterState(status: CourseStatusFilter.completed),
        viewMode: ListViewMode.table,
      );
      await tester.tap(find.widgetWithText(FilterChip, 'All'));
      await tester.pumpAndSettle();
      expect(c.read(courseFilterProvider).status, CourseStatusFilter.all);
    });

    testWidgets('a query that keeps nothing shows the no-match state', (
      tester,
    ) async {
      await pump(
        tester,
        ids: const {},
        filter: CourseFilterState(
          query: ConditionNode(
            FieldPath(['agency']),
            QueryOp.eq,
            const EnumValue('tdi'),
          ),
        ),
      );
      expect(find.byType(QueryNoMatchState), findsOneWidget);
    });
  });
}
