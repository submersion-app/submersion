import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/data/repositories/emergency_chamber_repository.dart';
import 'package:submersion/features/safety/domain/entities/emergency_info.dart';
import 'package:submersion/features/safety/presentation/pages/add_chamber_page.dart';
import 'package:submersion/features/safety/presentation/providers/emergency_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A repository whose create fails after its row was written.
class _ThrowingCreateRepository extends EmergencyChamberRepository {
  @override
  Future<EmergencyChamber> createChamber({
    String? id,
    required String name,
    required String country,
    required String phone,
    String? city,
    double? latitude,
    double? longitude,
    String? notes,
    String? diverId,
  }) async {
    await super.createChamber(
      id: id,
      name: name,
      country: country,
      phone: phone,
      city: city,
      notes: notes,
      diverId: diverId,
    );
    throw StateError('disk full');
  }
}

/// The add-chamber form as a new-record sitting (issue #4527, phase 4).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final diver in ['d1', 'd2']) {
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('$diver', '$diver', 1, 1)",
      );
    }
  });
  tearDown(tearDownTestDatabase);

  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/card',
      routes: [
        GoRoute(
          path: '/card',
          builder: (_, _) => const Scaffold(body: Text('CARD')),
          routes: [
            GoRoute(
              path: 'add-chamber',
              onExit: confirmLeaveRecordSitting,
              builder: (_, _) => const AddChamberPage(),
            ),
          ],
        ),
      ],
    );
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...base, ...overrides],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('d1');
    await tester.pumpAndSettle();
    unawaited(router.push('/card/add-chamber'));
    await tester.pumpAndSettle();
  }

  AppBarTextAction bar(WidgetTester tester, String label) => tester
      .widgetList<AppBarTextAction>(find.byType(AppBarTextAction))
      .firstWhere((a) => a.label == label);

  Future<void> tapBar(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(AppBarTextAction, label));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
    await tester.pump();
  }

  Future<void> fillRequired(WidgetTester tester) async {
    await type(tester, 'Name', 'Local Chamber');
    await type(tester, 'Country code (e.g. US)', 'us');
    await type(tester, 'Phone', '+1-555-0100');
  }

  String pageId(WidgetTester tester) => tester
      .state<RecordEditorHost<AddChamberPage, Object?>>(
        find.byType(AddChamberPage),
      )
      .newEditorRecordId;

  Future<int> chamberCount() async =>
      (await db.select(db.emergencyChambers).get()).length;

  testWidgets(
    'the bar is the tinted Cancel and Save bar; no Save in the body',
    (tester) async {
      await pump(tester);

      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(find.text('Add chamber'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(BackButton), findsNothing);
    },
  );

  testWidgets('a blank form has Save disabled; Cancel closes without asking', (
    tester,
  ) async {
    await pump(tester);

    expect(bar(tester, 'Save').onPressed, isNull);
    await tapBar(tester, 'Cancel');

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('CARD'), findsOneWidget);
  });

  testWidgets('Back after typing asks; Discard returns to the card', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'Name', 'Local Chamber');

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    unawaited(navigator.maybePop());
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('CARD'), findsOneWidget);
    expect(await chamberCount(), 0);
  });

  testWidgets('a missing name, country or phone writes nothing', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'City', 'Testville');
    await tapBar(tester, 'Save');

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Country code is required'), findsOneWidget);
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(await chamberCount(), 0);
    expect(find.byType(AddChamberPage), findsOneWidget);
  });

  testWidgets('Save creates the chamber under the page id for the diver', (
    tester,
  ) async {
    await pump(tester);
    final id = pageId(tester);
    await fillRequired(tester);
    await tapBar(tester, 'Save');

    final rows = await db.select(db.emergencyChambers).get();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.id, id);
    expect(row.diverId, 'd1');
    expect(row.country, 'US');
    expect(row.city, isNull);
    expect(row.notes, isNull);

    final labels = await db
        .customSelect(
          "SELECT label FROM change_log_operations "
          "WHERE label LIKE 'record_edit:%'",
        )
        .get();
    expect(labels, hasLength(1));
    final label = RecordEditLabel.decode(labels.single.read<String>('label'))!;
    expect(label.table, 'emergency_chambers');
    expect(label.id, id);
    expect(find.text('CARD'), findsOneWidget);
  });

  testWidgets('a create that throws keeps the form and says it failed', (
    tester,
  ) async {
    await pump(
      tester,
      overrides: [
        emergencyChamberRepositoryProvider.overrideWithValue(
          _ThrowingCreateRepository(),
        ),
      ],
    );
    await fillRequired(tester);
    await tapBar(tester, 'Save');

    expect(await chamberCount(), 0);
    expect(find.text('Local Chamber'), findsOneWidget);
    expect(
      find.text("Couldn't save your changes. Nothing was changed."),
      findsOneWidget,
    );
  });

  testWidgets('a chamber typed in closes on a diver switch, writing nothing', (
    tester,
  ) async {
    await pump(tester);
    await fillRequired(tester);

    unawaited(
      container.read(currentDiverIdProvider.notifier).setCurrentDiver('d2'),
    );
    await tester.pumpAndSettle();

    expect(find.text('CARD'), findsOneWidget);
    expect(await chamberCount(), 0);
  });

  testWidgets('with no active diver Save writes no chamber', (tester) async {
    // A chamber with no diver is a global one; the card hides Add then.
    await pump(
      tester,
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
    await fillRequired(tester);
    await tapBar(tester, 'Save');

    expect(await chamberCount(), 0);
    expect(find.byType(AddChamberPage), findsOneWidget);
    expect(
      find.text("Couldn't save your changes. Nothing was changed."),
      findsOneWidget,
    );
  });

  testWidgets(
    'opened with nothing under it, Cancel goes to the emergency card',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const card = '/settings/diver-profile/emergency-card';
      final router = GoRouter(
        initialLocation: '$card/add-chamber',
        routes: [
          GoRoute(
            path: card,
            builder: (_, _) => const Scaffold(body: Text('CARD')),
          ),
          GoRoute(
            path: '$card/add-chamber',
            onExit: confirmLeaveRecordSitting,
            builder: (_, _) => const AddChamberPage(),
          ),
        ],
      );
      final base = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: base,
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AddChamberPage), findsOneWidget);

      await tapBar(tester, 'Cancel');

      expect(find.text('CARD'), findsOneWidget);
    },
  );
}
