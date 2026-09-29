import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/query/presentation/widgets/query_chips_frame.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  final ann = ConditionNode(
    FieldPath(['name']),
    QueryOp.eq,
    const StringValue('Ann'),
  );
  final fav = ConditionNode(
    FieldPath(['favorite']),
    QueryOp.eq,
    const BoolValue(true),
  );

  Future<List<QueryNode?>> pump(WidgetTester tester, QueryNode? query) async {
    final changes = <QueryNode?>[];
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: QueryChipsFrame(
          root: buddyQueryEntity,
          query: query,
          onChanged: changes.add,
          child: const Text('BODY'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return changes;
  }

  testWidgets('no query shows only the body', (tester) async {
    await pump(tester, null);
    expect(find.text('BODY'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('one chip per condition; delete leaves the rest', (tester) async {
    final changes = await pump(tester, AndNode([ann, fav]));
    expect(find.byType(InputChip), findsNWidgets(2));
    tester.widget<InputChip>(find.byType(InputChip).first).onDeleted!();
    expect(changes, [fav]);
  });

  testWidgets('Clear clears the whole query', (tester) async {
    final changes = await pump(tester, ann);
    await tester.tap(find.text('Clear'));
    expect(changes, [null]);
  });

  testWidgets('the no-match state offers Clear', (tester) async {
    var cleared = 0;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: QueryNoMatchState(onClear: () => cleared++),
      ),
    );
    expect(find.text('Nothing matches this query'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    expect(cleared, 1);
  });
}
