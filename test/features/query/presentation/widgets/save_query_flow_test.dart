import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/widgets/save_query_flow.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// The save flow any query editor shares (#2365 PR 3).
void main() {
  late AppDatabase db;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  testWidgets('saves the query under the given subject', (tester) async {
    final node = ConditionNode(
      FieldPath(['difficulty']),
      QueryOp.eq,
      const EnumValue('advanced'),
    );
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        ],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => saveQueryFromEditor(
              context,
              ref,
              subject: QuerySubject.sites,
              node: node,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Hard sites');
    await tester.tap(find.text('Save'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    final rows = await tester.runAsync(() => db.select(db.savedQueries).get());
    expect(rows!.single.subject, 'sites');
    expect(rows.single.name, 'Hard sites');
  });
}
