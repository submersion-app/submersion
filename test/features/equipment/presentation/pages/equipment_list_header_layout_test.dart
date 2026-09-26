import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_section_colors.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_section_toggle.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_set_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
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

/// No sets, and no database behind them: switching to Sets must not reach one.
class _EmptySetList extends StateNotifier<AsyncValue<List<EquipmentSet>>>
    implements EquipmentSetListNotifier {
  _EmptySetList() : super(const AsyncValue.data(<EquipmentSet>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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
    equipmentSetListNotifierProvider.overrideWith((ref) => _EmptySetList()),
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

Widget _app(List<Override> overrides, {Locale locale = const Locale('en')}) {
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
      // Pinned: the assertions compare against strings loaded for a known
      // locale, and an unpinned app resolves against the host's instead.
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Size window,
  double? paneWidth,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = window;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    _app(await _overrides(paneWidth: paneWidth), locale: locale),
  );
  await tester.pumpAndSettle();
}

final _switcher = find.byKey(const ValueKey('equipment_section_toggle'));

/// The toggle precedes the actions: strictly above them, or to their left on a
/// shared row.
void _expectTogglePrecedesActions(WidgetTester tester) {
  final toggle = tester.getRect(_switcher);
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

    testWidgets('the wide pane keeps the toggle while selecting', (
      tester,
    ) async {
      await _pump(tester, window: const Size(1400, 900), paneWidth: 440);
      expect(_switcher, findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      // The master pane has no app bar above it, so if the header goes away
      // with the actions there is no way back to Sets without leaving
      // selection mode first.
      expect(
        _switcher,
        findsOneWidget,
        reason: 'the section toggle must outlive the action bar it scopes',
      );
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

  group('Equipment header title switcher', () {
    Future<AppLocalizations> en() =>
        AppLocalizations.delegate.load(const Locale('en'));

    for (final (label, window, pane) in <(String, Size, double?)>[
      ('desktop', const Size(1400, 900), 440),
      ('phone', const Size(390, 844), null),
    ]) {
      testWidgets('$label: the title is a tab per section', (tester) async {
        await _pump(tester, window: window, paneWidth: pane);
        final l10n = await en();

        // The section labels are the header's title, not a control beside it:
        // one tab per section, labelled with the section's own name.
        expect(
          find.descendant(of: _switcher, matching: find.byType(Tab)),
          findsNWidgets(2),
        );
        for (final name in [
          l10n.equipment_tab_equipment,
          l10n.equipment_tab_sets,
        ]) {
          expect(
            find.descendant(of: _switcher, matching: find.text(name)),
            findsOneWidget,
          );
        }
        expect(find.byType(SegmentedButton<int>), findsNothing);
      });
    }

    testWidgets('the two names sit together, packed like a title', (
      tester,
    ) async {
      await _pump(tester, window: const Size(1400, 900), paneWidth: 440);
      final l10n = await en();
      Rect label(String name) => tester.getRect(
        find.descendant(of: _switcher, matching: find.text(name)),
      );

      // A fixed TabBar would give each name half the header and strand the
      // second one mid-row; a title keeps them side by side.
      final gap =
          label(l10n.equipment_tab_sets).left -
          label(l10n.equipment_tab_equipment).right;
      expect(gap, inInclusiveRange(0, 24));
      // Packed from the start, one label padding in from the switcher's edge,
      // not pushed along by a stretched first slot.
      expect(
        label(l10n.equipment_tab_equipment).left -
            tester.getRect(_switcher).left,
        closeTo(8, 1),
      );
    });

    testWidgets('the selected section sits in a pill; hover matches it', (
      tester,
    ) async {
      await _pump(tester, window: const Size(390, 844));
      final bar = tester.widget<TabBar>(_switcher);
      final scheme = Theme.of(tester.element(_switcher)).colorScheme;
      final colors = EquipmentSectionColors.of(scheme);

      expect(bar.labelColor, colors.selected);
      expect(bar.unselectedLabelColor, colors.unselected);

      final pill = bar.indicator! as BoxDecoration;
      expect(pill.color, colors.pill);
      // The hover and focus highlight takes the pill's own shape, so it reads
      // as a preview of selection rather than a stray rectangle.
      expect(bar.splashBorderRadius, pill.borderRadius);
    });

    for (final (label, window, pane) in <(String, Size, double?)>[
      ('desktop', const Size(1400, 900), 440),
      ('phone', const Size(390, 844), null),
    ]) {
      testWidgets('$label: each highlight is centred on its name', (
        tester,
      ) async {
        await _pump(tester, window: window, paneWidth: pane);
        final l10n = await en();

        for (final name in [
          l10n.equipment_tab_equipment,
          l10n.equipment_tab_sets,
        ]) {
          final text = find.descendant(
            of: _switcher,
            matching: find.text(name),
          );
          final ink = find.ancestor(of: text, matching: find.byType(InkWell));
          // The highlight used to span the name plus 16px of empty space
          // after it, so it sat visibly off to one side.
          expect(
            (tester.getCenter(ink.first).dx - tester.getCenter(text).dx).abs(),
            lessThan(1.0),
            reason: '"$name" highlight is off-centre',
          );
        }
      });

      testWidgets('$label: the title text starts where pane titles do', (
        tester,
      ) async {
        await _pump(tester, window: window, paneWidth: pane);
        final l10n = await en();

        // 16px in from the header's leading edge, like every other titled
        // pane; the pill reaches into that margin rather than pushing the
        // text inward.
        final edge = pane == null
            ? 0.0
            : tester.getTopLeft(find.byType(EquipmentListContent)).dx;
        final text = tester.getTopLeft(
          find.descendant(
            of: _switcher,
            matching: find.text(l10n.equipment_tab_equipment),
          ),
        );
        expect(text.dx - edge, closeTo(16, 1));
      });
    }

    testWidgets('tapping the Sets label switches to Sets', (tester) async {
      await _pump(tester, window: const Size(390, 844));
      final l10n = await en();
      expect(find.byType(EquipmentSetListContent), findsNothing);

      await tester.tap(
        find.descendant(
          of: _switcher,
          matching: find.text(l10n.equipment_tab_sets),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EquipmentSetListContent), findsOneWidget);
      // Sets has no actions of its own, so its action row is gone with it.
      expect(find.byIcon(Icons.search), findsNothing);
    });

    for (final (label, window, pane) in <(String, Size, double?)>[
      ('a 440px pane', const Size(1400, 900), 440),
      ('a 320px phone', const Size(320, 700), null),
    ]) {
      testWidgets('French, the longest pair, fits $label', (tester) async {
        await _pump(
          tester,
          window: window,
          paneWidth: pane,
          locale: const Locale('fr'),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Phone header on one row', () {
    Future<AppLocalizations> en() =>
        AppLocalizations.delegate.load(const Locale('en'));
    final appBar = find.byType(AppBar);
    Finder inAppBar(Finder f) => find.descendant(of: appBar, matching: f);

    /// The narrowest phone the switcher and its four actions share a row on,
    /// measured in whatever font the test runs with: the switcher's natural
    /// width, the 8px title spacing on both sides, four 48px actions.
    Future<double> oneRowWidth(WidgetTester tester) async {
      await _pump(tester, window: const Size(600, 844));
      final l10n = await en();
      final style = tester
          .renderObject<RenderParagraph>(
            find.descendant(
              of: _switcher,
              matching: find.text(l10n.equipment_tab_equipment),
            ),
          )
          .text
          .style!;
      return EquipmentSectionToggle.naturalWidth(
            tester.element(_switcher),
            style,
            withAccentIcon: false,
          ) +
          2 * 8 +
          4 * kMinInteractiveDimension;
    }

    bool sameRow(WidgetTester tester) =>
        (tester.getCenter(_switcher).dy -
                tester.getCenter(find.byIcon(Icons.search)).dy)
            .abs() <
        1.0;

    testWidgets('where they fit, the switcher and actions share one row', (
      tester,
    ) async {
      final width = (await oneRowWidth(tester)).ceilToDouble();
      await _pump(tester, window: Size(width, 844));

      expect(inAppBar(find.byIcon(Icons.search)), findsOneWidget);
      expect(sameRow(tester), isTrue);

      // Deciding "it fits" wrongly would not overflow, the names would just
      // scroll out of sight, so check both are on screen at the boundary.
      final l10n = await en();
      final sets = find.descendant(
        of: _switcher,
        matching: find.text(l10n.equipment_tab_sets),
      );
      expect(
        tester.getRect(sets).right,
        lessThanOrEqualTo(tester.getRect(_switcher).right + 0.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a pixel narrower, the actions drop to a second row', (
      tester,
    ) async {
      final width = (await oneRowWidth(tester)).floorToDouble() - 1;
      await _pump(tester, window: Size(width, 844));

      expect(sameRow(tester), isFalse);
      expect(
        tester.getRect(_switcher).bottom,
        lessThanOrEqualTo(tester.getRect(find.byIcon(Icons.search)).top + 0.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the names use the 18px phone title size', (tester) async {
      await _pump(tester, window: const Size(390, 844));
      final l10n = await en();
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: _switcher,
          matching: find.text(l10n.equipment_tab_equipment),
        ),
      );
      expect(paragraph.text.style?.fontSize, 18);
    });

    testWidgets('Select items lives in the overflow menu', (tester) async {
      await _pump(tester, window: const Size(390, 844));
      final l10n = await en();

      expect(find.byIcon(Icons.checklist), findsNothing);

      await tester.tap(inAppBar(find.byIcon(Icons.more_vert)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.common_selection_enterTooltip));
      await tester.pumpAndSettle();

      expect(find.byType(SelectionAppBar), findsOneWidget);
      // The actions step aside while selecting, as the row they came from did.
      expect(inAppBar(find.byIcon(Icons.search)), findsNothing);
    });

    for (final (label, window, locale) in <(String, Size, Locale)>[
      ('French on a 390px phone', const Size(390, 844), const Locale('fr')),
      ('English on a 320px phone', const Size(320, 700), const Locale('en')),
    ]) {
      testWidgets('falls back to two rows for $label', (tester) async {
        await _pump(tester, window: window, locale: locale);

        final toggle = tester.getRect(_switcher);
        final action = tester.getRect(find.byIcon(Icons.search));
        expect(toggle.bottom, lessThanOrEqualTo(action.top + 0.5));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
