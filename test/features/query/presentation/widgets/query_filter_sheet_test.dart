import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/widgets/query_filter_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const now = 1735689600000;
  final ann = ConditionNode(
    FieldPath(['name']),
    QueryOp.eq,
    const StringValue('Ann'),
  );

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

  /// Pumps [home] over the test database with the diver's settings.
  Future<ProviderContainer> pumpHome(WidgetTester tester, Widget home) async {
    SharedPreferences.setMockInitialValues({currentDiverIdKey: 'me'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(c.dispose);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: home),
        ),
      ),
    );
    return c;
  }

  Future<List<QueryNode?>> open(WidgetTester tester, QueryNode? initial) async {
    SharedPreferences.setMockInitialValues({currentDiverIdKey: 'me'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(c.dispose);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final applied = <QueryNode?>[];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showQueryFilterSheet(
                  context,
                  subject: QuerySubject.buddies,
                  root: buddyQueryEntity,
                  initial: initial,
                  onApply: (ref, q) => applied.add(q),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    return applied;
  }

  testWidgets('Apply hands the typed query to onApply', (tester) async {
    final applied = await open(tester, null);
    await tester.enterText(find.byType(TextField).first, 'name = "Ann"');
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(applied, [ann]);
  });

  testWidgets('Clear then Apply hands null', (tester) async {
    final applied = await open(tester, ann);
    await tester.tap(find.byKey(const ValueKey('query_filter_sheet_clear')));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(applied, [null]);
  });

  testWidgets('Clear also clears a draft that never parsed', (tester) async {
    final applied = await open(tester, null);
    await tester.enterText(find.byType(TextField).first, 'name ~');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('query_filter_sheet_clear')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(applied, [null]);
  });

  testWidgets('QueryFilterAction edits its list\'s query provider', (
    tester,
  ) async {
    final query = StateProvider<QueryNode?>((ref) => null);
    final c = await pumpHome(
      tester,
      QueryFilterAction(
        provider: query,
        subject: QuerySubject.buddies,
        root: buddyQueryEntity,
      ),
    );
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);

    await tester.tap(find.byType(QueryFilterAction));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'name = "Ann"');
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(c.read(query), ann);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
  });

  testWidgets('Cancel applies nothing', (tester) async {
    final applied = await open(tester, ann);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(applied, isEmpty);
  });

  testWidgets('the button shows a badge only while a query is active', (
    tester,
  ) async {
    Future<void> pumpButton(bool active) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QueryFilterButton(active: active, onPressed: () {}),
        ),
      ),
    );
    await pumpButton(false);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    await pumpButton(true);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
  });
}
