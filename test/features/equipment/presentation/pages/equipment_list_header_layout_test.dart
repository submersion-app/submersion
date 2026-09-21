import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';

import '../../../../helpers/mock_providers.dart';

/// The Equipment/Sets toggle scopes the search / filter / sort / select
/// actions beside it, so it has to come first: on its own row above them, or
/// to their left when the two share a row. Issue #2256 is that the wide pane
/// rendered it after them.
///
/// These tests pin that ordering, and pin that no arrangement overflows across
/// the master pane's full 280-700px resize range.

class _MockEquipNotifier extends StateNotifier<AsyncValue<List<EquipmentItem>>>
    implements EquipmentListNotifier {
  _MockEquipNotifier() : super(const AsyncValue.data(<EquipmentItem>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _EmptyTagList extends StateNotifier<AsyncValue<List<Tag>>>
    implements TagListNotifier {
  _EmptyTagList() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<List<Override>> _overrides({double? paneWidth}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    equipmentByStatusProvider.overrideWith((ref, status) => <EquipmentItem>[]),
    activeEquipmentProvider.overrideWith((ref) async => <EquipmentItem>[]),
    equipmentListNotifierProvider.overrideWith((ref) => _MockEquipNotifier()),
    tagListNotifierProvider.overrideWith((ref) => _EmptyTagList()),
    equipmentListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
    equipmentSortProvider.overrideWith(
      (ref) => const SortState(
        field: EquipmentSortField.name,
        direction: SortDirection.ascending,
      ),
    ),
    if (paneWidth != null)
      masterPaneWidthProvider.overrideWith((ref) => paneWidth),
  ];
}

Widget _app(List<Override> overrides) {
  final router = GoRouter(
    initialLocation: '/equipment',
    routes: [
      GoRoute(
        path: '/equipment',
        builder: (context, state) => const EquipmentListPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, _) => const Scaffold(body: Text('new')),
          ),
          GoRoute(
            path: ':id',
            builder: (_, _) => const Scaffold(body: Text('detail')),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Size window,
  double? paneWidth,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = window;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(_app(await _overrides(paneWidth: paneWidth)));
  await tester.pumpAndSettle();
}

/// The toggle precedes the actions: strictly above them, or to their left on a
/// shared row.
void _expectTogglePrecedesActions(WidgetTester tester) {
  final toggle = tester.getRect(find.byType(SegmentedButton<int>).first);
  final action = tester.getRect(find.byIcon(Icons.search).first);

  final above = toggle.bottom <= action.top + 0.5;
  final leftOfOnSameRow =
      (toggle.center.dy - action.center.dy).abs() < 1.0 &&
      toggle.right <= action.left + 0.5;

  expect(
    above || leftOfOnSameRow,
    isTrue,
    reason:
        'toggle at $toggle must precede the actions at $action, either on the '
        'row above or to their left',
  );
}

void main() {
  group('Equipment header ordering (issue #2256)', () {
    testWidgets('wide mode puts the toggle before the actions', (tester) async {
      await _pump(tester, window: const Size(1400, 900), paneWidth: 440);
      _expectTogglePrecedesActions(tester);
    });

    testWidgets('phone mode puts the toggle before the actions', (
      tester,
    ) async {
      await _pump(tester, window: const Size(390, 844));
      _expectTogglePrecedesActions(tester);
    });
  });

  group('Equipment header fits the pane resize range (issue #2256)', () {
    for (final width in <double>[280, 400, 440, 700]) {
      testWidgets('no overflow at a ${width.toInt()}px master pane', (
        tester,
      ) async {
        await _pump(tester, window: const Size(1400, 900), paneWidth: width);
        expect(
          tester.takeException(),
          isNull,
          reason: 'the header overflowed at a ${width.toInt()}px pane',
        );
      });
    }

    testWidgets('no overflow on a 320px phone', (tester) async {
      await _pump(tester, window: const Size(320, 700));
      expect(tester.takeException(), isNull);
    });
  });

  group('Equipment header content (issue #2256)', () {
    testWidgets('the wide pane keeps the bulk-select action visible', (
      tester,
    ) async {
      await _pump(tester, window: const Size(1400, 900), paneWidth: 440);
      expect(find.byIcon(Icons.checklist), findsOneWidget);
    });

    testWidgets('the phone list body carries no heading of its own', (
      tester,
    ) async {
      await _pump(tester, window: const Size(390, 844));

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // The app bar owns the title and the toggle, so nothing below it should
      // repeat the word: it used to sit directly under the page title.
      expect(
        find.descendant(
          of: find.byType(TabBarView),
          matching: find.text(l10n.equipment_appBar_title),
        ),
        findsNothing,
      );
    });
  });
}
