import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_scrubber_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_add_fab.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../widgets/dive_list_trip_grouping_test.dart' show makeDive;
import '../widgets/dive_scrubber_index_override.dart';

class _AllLoaded extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _AllLoaded(List<DiveSummary> dives)
    : super(
        AsyncValue.data(
          PaginatedDiveListState(
            dives: dives,
            hasMore: false,
            totalCount: dives.length,
            revision: 1,
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoDives extends StateNotifier<AsyncValue<List<Dive>>>
    implements DiveListNotifier {
  _NoDives() : super(const AsyncValue.data(<Dive>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final dives = [for (var i = 0; i < 300; i++) makeDive('d$i')];
  final index = [
    for (final d in dives)
      DiveScrubberEntry(
        id: d.id,
        sortTimestamp: d.sortTimestamp,
        diveNumber: d.diveNumber,
        siteName: d.siteName,
      ),
  ];

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  late GoRouter router;

  Future<void> pumpPage(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final base = await getBaseOverrides();
    router = GoRouter(
      initialLocation: '/dives',
      routes: [
        GoRoute(path: '/dives', builder: (_, _) => const DiveListPage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
          diveListGroupTripsProvider.overrideWith((ref) => false),
          paginatedDiveListProvider.overrideWith((ref) => _AllLoaded(dives)),
          diveListNotifierProvider.overrideWith((ref) => _NoDives()),
          diveScrubberIndexOverride(() => index),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
      ),
    );
    await settle(tester);
  }

  /// The button is mounted either way; it is shown when scaled up and
  /// reachable.
  bool shown(WidgetTester tester) {
    final scale = tester.widget<AnimatedScale>(
      find.byKey(DiveListAddFab.scaleKey),
    );
    final ignoring = tester.widget<IgnorePointer>(
      find.byKey(DiveListAddFab.pointerKey),
    );
    expect(ignoring.ignoring, scale.scale == 0);
    return scale.scale == 1;
  }

  testWidgets('dragging the scrubber hides the add-dive button until release', (
    tester,
  ) async {
    await pumpPage(tester, const Size(400, 800));
    expect(shown(tester), isTrue);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -50),
    );
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await settle(tester);
    expect(shown(tester), isFalse);

    await gesture.up();
    await settle(tester);
    expect(shown(tester), isTrue);
  });

  testWidgets('the master-detail layout hides the button while scrubbing', (
    tester,
  ) async {
    await pumpPage(tester, const Size(1200, 800));
    expect(find.byType(MasterDetailScaffold), findsOneWidget);
    expect(shown(tester), isTrue);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveListPage)),
    );

    container.read(diveListScrubbingProvider.notifier).state = true;
    await settle(tester);
    expect(shown(tester), isFalse);

    container.read(diveListScrubbingProvider.notifier).state = false;
    await settle(tester);
    expect(shown(tester), isTrue);
  });

  testWidgets('a flip of the scrubbing flag rebuilds only the button', (
    tester,
  ) async {
    await pumpPage(tester, const Size(1200, 800));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveListPage)),
    );
    final rebuilt = <Type>{};
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      final widget = element.widget;
      if (widget is DiveListPage ||
          widget is DiveListContent ||
          widget is MasterDetailScaffold) {
        rebuilt.add(widget.runtimeType);
      }
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    container.read(diveListScrubbingProvider.notifier).state = true;
    await settle(tester);
    container.read(diveListScrubbingProvider.notifier).state = false;
    await settle(tester);

    expect(rebuilt, isEmpty);
    expect(shown(tester), isTrue);
  });

  group('master-detail while scrubbing', () {
    Future<ProviderContainer> hide(WidgetTester tester) async {
      await pumpPage(tester, const Size(1200, 800));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveListPage)),
      );
      container.read(diveListScrubbingProvider.notifier).state = true;
      await settle(tester);
      expect(shown(tester), isFalse);
      return container;
    }

    testWidgets('a tap on the hidden button reaches the row beneath it', (
      tester,
    ) async {
      final container = await hide(tester);
      final spot = tester.getCenter(find.byKey(DiveListAddFab.scaleKey));

      await tester.tapAt(spot);
      await settle(tester);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.queryParameters,
        contains('selected'),
      );
      container.read(diveListScrubbingProvider.notifier).state = false;
      await settle(tester);
    });

    testWidgets('the hidden button leaves no create semantics node', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final container = await hide(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DiveListPage)),
      );
      List<String> labels() {
        final out = <String>[];
        bool visit(SemanticsNode node) {
          out
            ..add(node.label)
            ..add(node.tooltip);
          node.visitChildren(visit);
          return true;
        }

        visit(tester.getSemantics(find.byType(MasterDetailScaffold)));
        return out;
      }

      expect(
        labels().where(
          (l) =>
              l == l10n.accessibility_label_createNewItem ||
              l == l10n.diveLog_listPage_fab_logDive,
        ),
        isEmpty,
      );
      container.read(diveListScrubbingProvider.notifier).state = false;
      await settle(tester);
      expect(
        labels().where((l) => l == l10n.diveLog_listPage_fab_logDive),
        isNotEmpty,
      );
      semantics.dispose();
    });

    testWidgets('tab traversal skips the hidden button', (tester) async {
      final container = await hide(tester);
      bool inFab(FocusNode node) =>
          node.context?.findAncestorWidgetOfExactType<FloatingActionButton>() !=
          null;
      final traversable = FocusManager.instance.rootScope.traversalDescendants;
      expect(traversable.where(inFab), isEmpty);

      container.read(diveListScrubbingProvider.notifier).state = false;
      await settle(tester);
      expect(
        FocusManager.instance.rootScope.traversalDescendants.where(inFab),
        isNotEmpty,
      );
    });
  });
}
