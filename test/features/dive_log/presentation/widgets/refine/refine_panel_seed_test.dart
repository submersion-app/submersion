import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_panel.dart';

import 'refine_test_host.dart';

final _target = StateProvider<DiveFilterState>(
  (ref) => const DiveFilterState(),
);

/// The dive table's Add filter opens the Refine panel on a seeded draft
/// (#2984).
void main() {
  final rule = ConditionNode(
    FieldPath(['depth']),
    QueryOp.gte,
    const NumberValue(30, null),
  );

  testWidgets('a seeded draft opens the Rules group on the Builder tab', (
    tester,
  ) async {
    await openRefinePanel(
      tester,
      target: _target,
      initialDraft: const DiveFilterState().copyWith(query: rule),
      startOnRulesBuilder: true,
    );
    final tabs = tester.widget<TabBar>(find.byType(TabBar).first);
    expect(tabs.controller!.index, 1);
  });

  testWidgets('dismissing leaves the live filter untouched', (tester) async {
    final container = await openRefinePanel(
      tester,
      target: _target,
      initialDraft: const DiveFilterState().copyWith(query: rule),
      startOnRulesBuilder: true,
    );
    await tester.tap(find.byKey(kRefineCancelKey));
    await tester.pumpAndSettle();
    expect(container.read(_target).query, isNull);
  });

  testWidgets('Show applies the seeded rule', (tester) async {
    final container = await openRefinePanel(
      tester,
      target: _target,
      initialDraft: const DiveFilterState().copyWith(query: rule),
      startOnRulesBuilder: true,
    );
    await tester.tap(find.byKey(kRefineApplyKey));
    await tester.pumpAndSettle();
    expect(container.read(_target).query, rule);
  });
}
