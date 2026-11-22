import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart'
    show AppSettings;
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/new_diver_page.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';

import '../../../../helpers/test_database.dart';
import 'diver_profile_harness.dart';

/// A repository whose create fails after its rows were written.
class _ThrowingCreateRepository extends DiverRepository {
  @override
  Future<Diver> createDiver(Diver diver, {AppSettings? settings}) async {
    await super.createDiver(diver, settings: settings);
    throw StateError('disk full');
  }
}

/// The new-diver page as a new-record sitting (issue #4527, phase 4).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedDiver(profileDiver(id: 'a', name: 'Alice'));
    await seedDiver(profileDiver(id: 'b', name: 'Bob'));
  });
  tearDown(tearDownTestDatabase);

  Future<void> pump(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) => pumpProfilePage(
    tester,
    path: 'new',
    page: const NewDiverPage(),
    activeDiverId: 'a',
    overrides: overrides,
  );

  String pageId(WidgetTester tester) => tester
      .state<RecordEditorHost<NewDiverPage, Object?>>(find.byType(NewDiverPage))
      .newEditorRecordId;

  Future<int> diverCount() async => (await db.select(db.divers).get()).length;

  Future<void> pickSex(WidgetTester tester, String option) async {
    await tester.tap(find.byKey(const Key('personalInfo_sex')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  testWidgets('a blank new diver has Save disabled; Cancel closes without '
      'asking', (tester) async {
    await pump(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text('Create Diver'), findsOneWidget);
    expect(barAction(tester, 'Save').onPressed, isNull);
    await tapBar(tester, 'Cancel');

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('typing a name enables Save; Back then asks', (tester) async {
    await pump(tester);
    await typeInto(tester, 'Name *', 'Carlos');

    expect(barAction(tester, 'Save').onPressed, isNotNull);
    await back(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Save creates the diver under the page id, with its settings', (
    tester,
  ) async {
    await pump(tester);
    final id = pageId(tester);
    await typeInto(tester, 'Name *', ' Carlos Charlie ');
    await tapBar(tester, 'Save');

    final created = (await storedDiver(id))!;
    expect(created.name, 'Carlos Charlie');
    final settings = await (db.select(
      db.diverSettings,
    )..where((t) => t.diverId.equals(id))).get();
    expect(settings, hasLength(1));
    final written = await sittings(db);
    expect(written, hasLength(1));
    expect(written.single.table, 'divers');
    expect(written.single.id, id);
  });

  testWidgets('a new diver is created with sex and birth year', (tester) async {
    await pump(tester);
    final id = pageId(tester);
    await typeInto(tester, 'Name *', 'Carlos Charlie');
    await pickSex(tester, 'Male');
    await typeInto(tester, 'Birth year', '1990');
    await tapBar(tester, 'Save');

    final created = (await storedDiver(id))!;
    expect(created.sex, DiverSex.male);
    expect(created.birthYear, 1990);
  });

  testWidgets('the new diver becomes active and nothing asks about the page', (
    tester,
  ) async {
    await pump(tester);
    final id = pageId(tester);
    await typeInto(tester, 'Name *', 'Carlos');
    await tapBar(tester, 'Save');

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Hub'), findsOneWidget);
    expect(profileContainer(tester).read(currentDiverIdProvider), id);
  });

  // A page underneath may hold unsaved work, which a switch would drop
  // (#3422).
  testWidgets('a new diver waits on the page underneath before taking over', (
    tester,
  ) async {
    final guard =
        AppExitGuard(
          retryExit: () async {},
          preventWindowClose: (_) async {},
          revealWindow: () async {},
        )..hold(
          AppExitBlocker(
            hasUnsavedWork: () => true,
            confirmLeaving: () async => false,
          ),
        );
    await pump(
      tester,
      overrides: [appExitGuardProvider.overrideWithValue(guard)],
    );
    final id = pageId(tester);
    await typeInto(tester, 'Name *', 'Carlos');
    await tapBar(tester, 'Save');

    expect(await storedDiver(id), isNotNull);
    expect(profileContainer(tester).read(currentDiverIdProvider), 'a');
  });

  testWidgets('a create that throws keeps the form and leaves no diver', (
    tester,
  ) async {
    await pump(
      tester,
      overrides: [
        diverRepositoryProvider.overrideWithValue(_ThrowingCreateRepository()),
      ],
    );
    final id = pageId(tester);
    await typeInto(tester, 'Name *', 'Carlos');
    await tapBar(tester, 'Save');

    expect(await storedDiver(id), isNull);
    expect(await diverCount(), 2);
    expect(find.text('Carlos'), findsOneWidget);
    expect(
      find.text("Couldn't save your changes. Nothing was changed."),
      findsOneWidget,
    );
  });

  testWidgets('an empty name or a bad birth year writes nothing', (
    tester,
  ) async {
    await pump(tester);
    await typeInto(tester, 'Name *', '  ');
    await tapBar(tester, 'Save');
    expect(find.text('Name is required'), findsOneWidget);

    await typeInto(tester, 'Name *', 'Carlos');
    await typeInto(tester, 'Birth year', '1899');
    await tapBar(tester, 'Save');
    expect(find.textContaining('Enter a year from 1900'), findsOneWidget);

    expect(await diverCount(), 2);
    expect(find.byType(NewDiverPage), findsOneWidget);
  });

  testWidgets(
    'a new diver typed in closes on a diver switch, writing nothing',
    (tester) async {
      await pump(tester);
      await typeInto(tester, 'Name *', 'Carlos');

      await switchWithoutAsking(tester, 'b');

      expect(find.text('Hub'), findsOneWidget);
      expect(await diverCount(), 2);
    },
  );

  testWidgets('opened with nothing under it, Cancel goes to the hub', (
    tester,
  ) async {
    await pumpProfilePage(
      tester,
      path: 'new',
      page: const NewDiverPage(),
      alone: true,
    );
    expect(find.byType(NewDiverPage), findsOneWidget);

    await tapBar(tester, 'Cancel');

    expect(find.text('Hub'), findsOneWidget);
  });
}
