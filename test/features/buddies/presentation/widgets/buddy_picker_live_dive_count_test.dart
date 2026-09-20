import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_picker.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/pump_until.dart';
import '../../../../helpers/test_database.dart';

final _now = DateTime(2024, 1, 1);

Future<void> _insertDiver() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
}

void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(640, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _buildPicker(MockCurrentDiverIdNotifier diverIdNotifier) {
  return ProviderScope(
    overrides: [
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BuddyPicker(selectedBuddies: const [], onChanged: (_) {}),
      ),
    ),
  );
}

void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;
  late BuddyRepository buddyRepo;

  setUp(() async {
    await setUpTestDatabase();
    await _insertDiver();
    buddyRepo = BuddyRepository();
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // Issue #2084: the "Add buddy" search sheet kept showing a stale dive
  // count because buddySearchWithDiveCountProvider, unlike its sibling
  // allBuddiesWithDiveCountProvider, never subscribed to dives-table
  // changes at all. This exercises the real providers end to end (no
  // dive-count provider overrides) against a real in-memory database.
  testWidgets(
    'the search sheet reflects a buddy linked to a dive while it stays open '
    '(issue #2084)',
    (tester) async {
      _useTallScreen(tester);

      final database = DatabaseService.instance.database;
      final buddy = await buddyRepo.createBuddy(
        Buddy(
          id: '',
          name: 'Umberto',
          diverId: 'diver-1',
          createdAt: _now,
          updatedAt: _now,
        ),
      );
      await database.customStatement(
        "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
        "VALUES ('dive-1', 1000, 1000, 1000)",
      );

      await tester.pumpWidget(_buildPicker(diverIdNotifier));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Search for the buddy, which keeps buddySearchWithDiveCountProvider('umb')
      // alive for the rest of the test, mirroring the reported scenario.
      await tester.enterText(find.byType(TextField), 'umb');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Umberto'), findsOneWidget);
      expect(find.text('1 dive'), findsNothing);

      // A sync pull applies a remote buddy link straight to dive_buddies and
      // deliberately never restamps the parent dive (#1769/#1915) -- unlike
      // buddyRepo.addBuddyToDive, which also touches `dives`, this is the
      // write that actually exercises watchDivesChangesWithBuddyLinks'
      // dive_buddies coverage.
      await database
          .into(database.diveBuddies)
          .insert(
            db.DiveBuddiesCompanion(
              id: const Value('link-1'),
              diveId: const Value('dive-1'),
              buddyId: Value(buddy.id),
              role: const Value(DiveRole.buddyId),
              createdAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );

      // Interval matches watchDivesChangesWithBuddyLinks' debounce window.
      await pumpUntil(
        tester,
        () => tester.any(find.text('1 dive')),
        interval: const Duration(milliseconds: 350),
        maxFrames: 10,
        reason:
            'the still-open search sheet must pick up the freshly linked '
            'dive without the query changing or the sheet being reopened',
      );
    },
  );
}
