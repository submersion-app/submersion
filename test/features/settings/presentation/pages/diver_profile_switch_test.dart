import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/medical_info_edit_page.dart';

import '../../../../helpers/test_database.dart';
import 'diver_profile_harness.dart';

/// The diver profile pages and a change of the active diver (issue #4527,
/// phase 4, decision 7): a page edits the diver it opened with, and closes
/// back to the hub when another diver becomes active, however that happens.
/// Before phase 4 a page saved onto whoever was active at Save.
void main() {
  late AppDatabase db;
  late Diver alice;
  late Diver bob;

  setUp(() async {
    db = await setUpTestDatabase();
    alice = profileDiver(id: 'a', name: 'Alice', allergies: 'Penicillin');
    bob = profileDiver(id: 'b', name: 'Bob', allergies: 'None');
    await seedDiver(alice);
    await seedDiver(bob);
  });
  tearDown(tearDownTestDatabase);

  Future<void> openMedical(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) => pumpProfilePage(
    tester,
    path: 'medical',
    page: const MedicalInfoEditPage(),
    activeDiverId: 'a',
    overrides: overrides,
  );

  /// Neither diver's medical details changed.
  Future<void> expectBothUnchanged() async {
    expect((await storedDiver('a'))!.allergies, 'Penicillin');
    expect((await storedDiver('b'))!.allergies, 'None');
  }

  testWidgets(
    'a switch with unsaved changes asks; Discard closes and writes neither diver',
    (tester) async {
      await openMedical(tester);
      await typeInto(tester, 'Allergies', 'Latex');

      await switchAsTheSwitcherDoes(tester, 'b');
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('Hub'), findsOneWidget);
      expect(find.byType(MedicalInfoEditPage), findsNothing);
      expect(profileContainer(tester).read(currentDiverIdProvider), 'b');
      await expectBothUnchanged();
      expect(await sittings(db), isEmpty);
    },
  );

  testWidgets(
    'Keep editing on the switch question keeps the page and the diver',
    (tester) async {
      await openMedical(tester);
      await typeInto(tester, 'Allergies', 'Latex');

      await switchAsTheSwitcherDoes(tester, 'b');
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      expect(find.text('Latex'), findsOneWidget);
      expect(profileContainer(tester).read(currentDiverIdProvider), 'a');
    },
  );

  testWidgets('a switch that does not ask closes the page and writes nothing', (
    tester,
  ) async {
    await openMedical(tester);
    await typeInto(tester, 'Allergies', 'Latex');

    // The misplaced logbook banner switches without asking.
    await switchWithoutAsking(tester, 'b');

    expect(find.text('Hub'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await expectBothUnchanged();
  });

  testWidgets(
    'a Save held while the diver resolves, then a switch, writes neither diver',
    (tester) async {
      Completer<void>? gate;
      await openMedical(
        tester,
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async {
            final id = ref.watch(currentDiverIdProvider);
            await gate?.future;
            return id;
          }),
        ],
      );
      await typeInto(tester, 'Allergies', 'Latex');

      // Save waits on the diver; meanwhile Bob becomes active.
      gate = Completer<void>();
      profileContainer(tester).invalidate(validatedCurrentDiverIdProvider);
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      unawaited(
        profileContainer(
          tester,
        ).read(currentDiverIdProvider.notifier).setCurrentDiver('b'),
      );
      await tester.pump();
      gate.complete();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Hub'), findsOneWidget);
      await expectBothUnchanged();
      expect(await sittings(db), isEmpty);
    },
  );

  testWidgets('the active diver deleted elsewhere closes the page', (
    tester,
  ) async {
    await openMedical(tester);
    await typeInto(tester, 'Allergies', 'Latex');

    // Deleted by a sync, say: the active diver resolves to Bob.
    await deleteDiverRow(db, 'a');
    await tester.pumpAndSettle();

    expect(find.text('Hub'), findsOneWidget);
    expect((await storedDiver('b'))!.allergies, 'None');
  });
}
