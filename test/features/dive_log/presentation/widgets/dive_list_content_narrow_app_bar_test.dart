import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// #3076: the app bar's title was squeezed to a few characters by four
/// action icons (map, search, sort, overflow) on any host narrower than the
/// fixed 440dp master-detail pane (`_buildCompactAppBar`) or a narrow phone
/// (`_buildAppBar`). Sort folds into the existing overflow menu below that
/// width instead, freeing room for the title; wide hosts are unaffected.
class _MockPaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _MockPaginatedNotifier(List<DiveSummary> dives)
    : super(
        AsyncValue.data(PaginatedDiveListState(dives: dives, hasMore: false)),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<Widget> buildContent({required bool showAppBar}) async {
    final summaries = [
      DiveSummary.fromDive(
        Dive(id: 'd1', dateTime: DateTime(2026, 3, 15), diveNumber: 1),
      ),
    ];
    final base = await getBaseOverrides();

    return testApp(
      locale: const Locale('en'),
      overrides: [
        ...base,
        diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
        diveFilterProvider.overrideWith((ref) => const DiveFilterState()),
        paginatedDiveListProvider.overrideWith(
          (ref) => _MockPaginatedNotifier(summaries),
        ),
      ],
      child: DiveListContent(showAppBar: showAppBar),
    );
  }

  testWidgets('a wide standalone app bar keeps Sort as its own icon', (
    tester,
  ) async {
    await tester.pumpWidget(await buildContent(showAppBar: true));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.sort), findsOneWidget);
  });

  testWidgets('a narrow standalone app bar folds Sort into the overflow menu', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(await buildContent(showAppBar: true));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.sort), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Sort'), findsOneWidget);
  });

  testWidgets('the folded Sort menu entry opens the sort sheet', (
    tester,
  ) async {
    // 400dp, not 360dp: still well under the 480dp fold threshold, but
    // wide enough to dodge an unrelated, pre-existing overflow in
    // SortBottomSheet's own row at very narrow widths (not part of #3076).
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(await buildContent(showAppBar: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort'));
    await tester.pumpAndSettle();

    expect(find.text('Sort Dives'), findsOneWidget);
  });

  testWidgets('a wide master-detail compact bar keeps Sort as its own icon', (
    tester,
  ) async {
    await tester.pumpWidget(await buildContent(showAppBar: false));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.sort), findsOneWidget);
  });

  testWidgets('a narrow master-detail compact bar (the fixed 440dp side pane) '
      'folds Sort into the overflow menu', (tester) async {
    final base = await getBaseOverrides();
    final summaries = [
      DiveSummary.fromDive(
        Dive(id: 'd1', dateTime: DateTime(2026, 3, 15), diveNumber: 1),
      ),
    ];

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
          diveFilterProvider.overrideWith((ref) => const DiveFilterState()),
          paginatedDiveListProvider.overrideWith(
            (ref) => _MockPaginatedNotifier(summaries),
          ),
        ],
        // The real master pane fixes its width at kRefinePanelSideWidth's
        // sibling constant for the dive list master-detail pane (440dp,
        // see MasterDetailScaffold), well below the 480dp fold threshold.
        child: const SizedBox(
          width: 440,
          height: 800,
          child: DiveListContent(showAppBar: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.sort), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Sort'), findsOneWidget);
  });

  testWidgets("the compact bar's folded Sort menu entry opens the sort sheet", (
    tester,
  ) async {
    final base = await getBaseOverrides();
    final summaries = [
      DiveSummary.fromDive(
        Dive(id: 'd1', dateTime: DateTime(2026, 3, 15), diveNumber: 1),
      ),
    ];

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
          diveFilterProvider.overrideWith((ref) => const DiveFilterState()),
          paginatedDiveListProvider.overrideWith(
            (ref) => _MockPaginatedNotifier(summaries),
          ),
        ],
        // 440dp, not 360dp: the real master pane's own width, wide enough
        // to dodge the unrelated SortBottomSheet overflow at very narrow
        // widths (see the standalone-bar test above for the same reason).
        child: const SizedBox(
          width: 440,
          height: 800,
          child: DiveListContent(showAppBar: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort'));
    await tester.pumpAndSettle();

    expect(find.text('Sort Dives'), findsOneWidget);
  });
}
