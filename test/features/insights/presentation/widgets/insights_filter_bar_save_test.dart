import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_filter_bar.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_group_menu.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Saving from the selector end to end: the real dialog, repository, name
/// index and change stream, with a tag so the saved query comes back carrying
/// the tag's name in place of the id the filter holds (#3479).
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
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 't-dry',
            diverId: const Value('me'),
            name: 'Drysuit',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Finder inBar(String text) => find.descendant(
    of: find.byType(InsightsFilterBar),
    matching: find.text(text),
  );

  Future<void> settleDatabase(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a saved filter takes its name in the bar at once', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          insightsFilterProvider.overrideWith(
            (ref) => const DiveFilterState(tagIds: ['t-dry']),
          ),
          filteredDiveStatisticsProvider.overrideWith(
            (ref) async => DiveStatistics(
              totalDives: 24,
              totalTimeSeconds: 0,
              maxDepth: 0,
              avgMaxDepth: 0,
              totalSites: 0,
            ),
          ),
        ],
        child: const Scaffold(body: InsightsFilterBar()),
      ),
    );
    await settleDatabase(tester);
    expect(inBar('Custom filter'), findsOneWidget);

    await tester.tap(find.byKey(kInsightsGroupMenuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save current filter...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Drysuit dives');
    await tester.tap(find.text('Save'));
    await settleDatabase(tester);

    final rows = await tester.runAsync(() => db.select(db.savedQueries).get());
    expect(rows!.single.name, 'Drysuit dives');
    expect(rows.single.subject, 'dives');
    expect(rows.single.diverId, 'me');
    expect(inBar('Drysuit dives'), findsOneWidget);
    expect(inBar('Custom filter'), findsNothing);
  });
}
