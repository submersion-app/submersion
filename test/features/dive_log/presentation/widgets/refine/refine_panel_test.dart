import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_panel.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';

import 'refine_test_host.dart';

void main() {
  final seeded = DiveFilterState(
    minDepth: 30,
    query: TextNode(['manta']),
    axesSuspended: true,
  );
  StateProvider<DiveFilterState> target() =>
      StateProvider<DiveFilterState>((ref) => seeded);

  testWidgets('Cancel leaves the filter as it was', (tester) async {
    final t = target();
    final c = await openRefinePanel(tester, target: t);
    await tester.tap(find.byKey(kRefineCancelKey));
    await tester.pumpAndSettle();
    expect(c.read(t), seeded);
    expect(find.byType(RefinePanel), findsNothing);
  });

  // Review Focus 2.
  testWidgets('Clear all then Cancel changes nothing', (tester) async {
    final t = target();
    final c = await openRefinePanel(tester, target: t);
    await tester.tap(find.byKey(kRefineClearAllKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kRefineCancelKey));
    await tester.pumpAndSettle();
    expect(c.read(t), seeded);
  });

  testWidgets('Clear all then Show clears everything', (tester) async {
    final t = target();
    final c = await openRefinePanel(tester, target: t);
    await tester.tap(find.byKey(kRefineClearAllKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kRefineApplyKey));
    await tester.pumpAndSettle();
    expect(c.read(t), const DiveFilterState());
  });

  testWidgets('Show applies the draft and leaves All dives', (tester) async {
    final t = target();
    final c = await openRefinePanel(tester, target: t);
    await tester.tap(find.byKey(kRefineApplyKey));
    await tester.pumpAndSettle();
    expect(c.read(t), seeded.copyWith(axesSuspended: false));
  });

  testWidgets('the button counts, holds its count while the next loads', (
    tester,
  ) async {
    final pending = Completer<int>();
    final t = target();
    await openRefinePanel(
      tester,
      target: t,
      count: (draft) => draft == seeded ? 2 : pending.future,
    );
    expect(find.text('Show 2 dives'), findsOneWidget);
    await tester.tap(find.byKey(kRefineClearAllKey));
    await tester.pump();
    expect(find.text('Show 2 dives'), findsOneWidget);
    pending.complete(1);
    await tester.pumpAndSettle();
    expect(find.text('Show 1 dive'), findsOneWidget);
  });

  testWidgets('a failed count reads Show dives', (tester) async {
    final t = target();
    await openRefinePanel(
      tester,
      target: t,
      count: (_) => throw StateError('boom'),
    );
    expect(find.text('Show dives'), findsOneWidget);
  });

  // Spec 5.4 (#2773): a saved search is the whole search; the axes clear.
  testWidgets('a saved query loads as the whole search, axes cleared', (
    tester,
  ) async {
    final depth = ConditionNode(
      FieldPath(['depth']),
      QueryOp.gt,
      const NumberValue(40, null),
    );
    final t = target();
    final c = await openRefinePanel(
      tester,
      target: t,
      saved: [
        SavedQueryLoad(
          SavedQuery(
            id: 's',
            subject: 'dives',
            name: 'Deep',
            queryJson: '{}',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          node: depth,
        ),
      ],
    );
    await tester.tap(find.widgetWithText(ActionChip, 'Deep'));
    await tester.pumpAndSettle();
    expect(c.read(t), DiveFilterState(query: depth));
    expect(find.byType(RefinePanel), findsNothing);
  });

  // #2989: a search built only in the GUI groups saves, its axes lowered
  // into the query as Show would apply them (All dives lifted).
  testWidgets('Save stores the whole draft, GUI axes and no rule', (
    tester,
  ) async {
    final saved = <QueryNode>[];
    final t = StateProvider<DiveFilterState>(
      (ref) => const DiveFilterState(minDepth: 30, axesSuspended: true),
    );
    await openRefinePanel(
      tester,
      target: t,
      extra: [
        diveSearchSaverProvider.overrideWithValue(
          (context, ref, node) async => saved.add(node),
        ),
      ],
    );
    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save query'));
    await tester.pumpAndSettle();
    expect(saved, [
      ConditionNode(
        FieldPath(['depth']),
        QueryOp.gte,
        const NumberValue(30, null),
      ),
    ]);
  });

  testWidgets('Save is disabled while the draft sets nothing', (tester) async {
    final t = StateProvider<DiveFilterState>((ref) => const DiveFilterState());
    await openRefinePanel(tester, target: t);
    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();
    final save = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Save query'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(save.enabled, isFalse);
  });

  // Code review (#989): desktop draws no scroll thumb until a scroll starts,
  // so the panel keeps one visible to show more groups follow.
  testWidgets('the group list shows its scrollbar', (tester) async {
    await openRefinePanel(tester, target: target());
    final bar = tester.widget<Scrollbar>(
      find
          .descendant(
            of: find.byType(RefinePanel),
            matching: find.byType(Scrollbar),
          )
          .first,
    );
    expect(bar.thumbVisibility, isTrue);
  });

  // Code review: axes with no panel control (set by the buddy page,
  // Connections and Explore) survive Show.
  testWidgets('handoff axes survive Show', (tester) async {
    const handoff = DiveFilterState(
      siteIds: ['s1', 's2'],
      buddyId: 'b1',
      diveIds: ['d1'],
    );
    final t = StateProvider<DiveFilterState>((ref) => handoff);
    final c = await openRefinePanel(tester, target: t);
    await tester.tap(find.byKey(kRefineApplyKey));
    await tester.pumpAndSettle();
    expect(c.read(t), handoff);
  });

  // Code review: a computer deleted since the filter was set is not counted,
  // matching the dropdown, which shows All computers for it.
  testWidgets('a deleted computer does not count as set', (tester) async {
    final t = StateProvider<DiveFilterState>(
      (ref) => const DiveFilterState(computerId: 'gone'),
    );
    await openRefinePanel(
      tester,
      target: t,
      extra: [allDiveComputersProvider.overrideWith((ref) async => const [])],
    );
    final gas = find.widgetWithText(ExpansionTile, 'Gas & Equipment');
    expect(
      find.descendant(of: gas, matching: find.text('Any')),
      findsOneWidget,
    );
  });
}
