import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_rules_group.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';

import 'group_test_host.dart';

void main() {
  Finder textField() => find.byType(TextField).first;

  Future<GroupHarness> pump(
    WidgetTester tester, {
    DiveFilterState initial = const DiveFilterState(),
  }) => pumpGroup(
    tester,
    (d, on) => RefineRulesGroup(draft: d, onChanged: on),
    initial: initial,
    overrides: [
      queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
    ],
  );

  testWidgets('a typed query reaches the draft, keeping other axes', (
    tester,
  ) async {
    final h = await pump(
      tester,
      initial: const DiveFilterState(computerId: 'dc-1'),
    );
    await tester.enterText(textField(), 'depth > 30');
    await tester.pump();
    expect(
      h.draft.query,
      ConditionNode(
        FieldPath(['depth']),
        QueryOp.gt,
        const NumberValue(30, null),
      ),
    );
    expect(h.draft.computerId, 'dc-1');
  });

  testWidgets('an existing query prints into the field', (tester) async {
    await pump(
      tester,
      initial: DiveFilterState(
        query: ConditionNode(
          FieldPath(['depth']),
          QueryOp.gt,
          const NumberValue(30, null),
        ),
      ),
    );
    expect(
      tester.widget<TextField>(textField()).controller!.text,
      'depth > 30',
    );
  });

  testWidgets('Save without a diver profile says why', (tester) async {
    await pump(
      tester,
      initial: DiveFilterState(
        query: ConditionNode(
          FieldPath(['depth']),
          QueryOp.gt,
          const NumberValue(30, null),
        ),
      ),
    );
    await tester.tap(find.text('Save query'));
    await tester.pumpAndSettle();
    expect(find.text('Create a diver profile to save queries'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  test('declares its field', () {
    expect(RefineRulesGroup.fields, {'query'});
    expect(RefineRulesGroup.activeCount(const DiveFilterState()), 0);
    expect(
      RefineRulesGroup.activeCount(DiveFilterState(query: TextNode(['a']))),
      1,
    );
  });
}
