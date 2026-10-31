import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/presentation/pages/change_log_page.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../core/database/change_log/change_log_support.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

final _activeDiver = StateProvider<String>((ref) => 'me');

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await insertDiver(db, 'me');
    await insertDiver(db, 'them');
    await insertDive(db, 'mine', diverId: 'me', notes: 'Calm');
    await insertDive(db, 'theirs', diverId: 'them', notes: 'Flat');
    await ChangeLogRepository().settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
  });
  tearDown(tearDownTestDatabase);

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    String? rootTable,
    String? rootId,
    AppSettings settings = const AppSettings(),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.reset);
    final notifier = MockSettingsNotifier(settings);
    final overrides = await tester.runAsync(
      () => getBaseOverrides(settingsNotifier: notifier),
    );
    final container = ProviderContainer(
      overrides: [
        ...overrides!,
        validatedCurrentDiverIdProvider.overrideWith(
          (ref) async => ref.watch(_activeDiver),
        ),
      ].cast(),
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              ChangeLogPage(rootTable: rootTable, rootId: rootId),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
    return container;
  }

  testWidgets('feed shows two changed fields and +1 more', (tester) async {
    await tester.runAsync(
      () => db.customStatement(
        "UPDATE dives SET notes = 'Current', max_depth = 30, avg_depth = 12 "
        "WHERE id = 'mine'",
      ),
    );

    await pump(tester);

    expect(find.text('+1 more'), findsOneWidget);
    expect(
      find.textContaining('Average Depth', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Max Depth', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Notes', findRichText: true), findsNothing);
  });

  testWidgets('values use the diver\'s units', (tester) async {
    await tester.runAsync(
      () => db.customStatement(
        "UPDATE dives SET max_depth = 30 WHERE id = 'mine'",
      ),
    );

    await pump(tester, settings: const AppSettings(depthUnit: DepthUnit.feet));

    expect(find.textContaining('98.4ft', findRichText: true), findsOneWidget);
  });

  testWidgets('old value is struck through', (tester) async {
    await tester.runAsync(
      () => db.customStatement(
        "UPDATE dives SET notes = 'Current' WHERE id = 'mine'",
      ),
    );

    await pump(tester);

    final struck = <String?>[];
    for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
      text.text.visitChildren((span) {
        if (span is TextSpan &&
            span.style?.decoration == TextDecoration.lineThrough) {
          struck.add(span.text);
        }
        return true;
      });
    }
    expect(struck, contains('Calm'));
  });

  testWidgets('a bulk entry shows its count', (tester) async {
    await tester.runAsync(() async {
      await insertDive(db, 'second', diverId: 'me');
      await clearLog(db);
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.import,
        label: 'Perdix',
        body: () async {
          await db.customStatement("UPDATE dives SET notes = 'A'");
        },
      );
    });

    await pump(tester);

    expect(find.text('View 2 records'), findsOneWidget);
    expect(find.text('Imported from Perdix'), findsOneWidget);
  });

  testWidgets('a bulk entry counts records, not changes', (tester) async {
    await tester.runAsync(() async {
      await insertDive(db, 'second', diverId: 'me');
      await clearLog(db);
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.import,
        label: 'Perdix',
        body: () async {
          await db.customStatement("UPDATE dives SET notes = 'A'");
          await db.customStatement("UPDATE dives SET notes = 'B'");
        },
      );
    });

    await pump(tester);

    expect(find.text('View 2 records'), findsOneWidget);
  });

  testWidgets('a deleted record reads as deleted', (tester) async {
    await tester.runAsync(
      () => db.customStatement("DELETE FROM dives WHERE id = 'mine'"),
    );

    await pump(tester);

    expect(find.text('Deleted'), findsOneWidget);
  });

  testWidgets('switching diver reloads the feed', (tester) async {
    await tester.runAsync(() async {
      await db.customStatement(
        "UPDATE dives SET notes = 'Mine now' WHERE id = 'mine'",
      );
      await db.customStatement(
        "UPDATE dives SET notes = 'Theirs now' WHERE id = 'theirs'",
      );
    });
    final container = await pump(tester);
    expect(find.textContaining('Mine now', findRichText: true), findsOneWidget);

    container.read(_activeDiver.notifier).state = 'them';
    await settle(tester);

    expect(find.textContaining('Mine now', findRichText: true), findsNothing);
    expect(
      find.textContaining('Theirs now', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('an empty log shows the empty state', (tester) async {
    await pump(tester);

    expect(find.text('No changes yet'), findsOneWidget);
  });

  testWidgets('the record filter shows that record\'s title', (tester) async {
    await tester.runAsync(() async {
      await db.customStatement(
        "UPDATE dives SET dive_number = 412 WHERE id = 'mine'",
      );
      await db.customStatement(
        "UPDATE dives SET notes = 'Other' WHERE id = 'theirs'",
      );
    });

    await pump(tester, rootTable: 'dives', rootId: 'mine');

    expect(find.text('Dive 412'), findsWidgets);
    expect(find.textContaining('Other', findRichText: true), findsNothing);
  });

  testWidgets('the filter chips narrow the feed', (tester) async {
    await tester.runAsync(() async {
      await db.customStatement(
        "UPDATE dives SET notes = 'Edited' WHERE id = 'mine'",
      );
      await db.customStatement(
        'INSERT INTO settings (key, value, updated_at) '
        "VALUES ('share_new_records_by_default', 'true', 0)",
      );
    });
    await pump(tester);
    expect(find.textContaining('Edited', findRichText: true), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Settings'));
    await settle(tester);

    expect(find.textContaining('Edited', findRichText: true), findsNothing);
  });

  testWidgets('entries are grouped by day', (tester) async {
    await tester.runAsync(
      () => db.customStatement(
        "UPDATE dives SET notes = 'Today' WHERE id = 'mine'",
      ),
    );

    await pump(tester);

    expect(find.text('Today'), findsOneWidget);
  });
}

/// Lets the feed finish, which needs real time for the database isolate.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 100));
}
