import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/emergency_contacts_edit_page.dart';
import 'package:submersion/features/settings/presentation/pages/medical_info_edit_page.dart';
import 'package:submersion/features/settings/presentation/pages/notes_edit_page.dart';
import 'package:submersion/features/settings/presentation/pages/personal_info_edit_page.dart';
import 'package:submersion/features/settings/presentation/pages/prior_experience_edit_page.dart';

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

  for (final change in [false, true]) {
    testWidgets('personal info closes on a switch (changed: $change)', (
      tester,
    ) async {
      await pumpProfilePage(
        tester,
        path: 'personal',
        page: const PersonalInfoEditPage(),
        activeDiverId: 'a',
      );
      if (change) await typeInto(tester, 'Email', 'alice@example.com');

      await switchWithoutAsking(tester, 'b');

      expect(find.text('Hub'), findsOneWidget);
      expect((await storedDiver('a'))!.email, isNull);
    });
  }

  // Every profile page, changed and then left by a switch that asks
  // nothing: the hub shows, and diver 'a' is as seeded.
  final pages = <String, (Widget, Future<void> Function(WidgetTester))>{
    'personal': (
      const PersonalInfoEditPage(),
      (t) => typeInto(t, 'Email', 'alice@example.com'),
    ),
    'medical': (
      const MedicalInfoEditPage(),
      (t) => typeInto(t, 'Allergies', 'Latex'),
    ),
    'emergency': (
      const EmergencyContactsEditPage(),
      (t) async {
        await t.enterText(
          find.widgetWithText(TextFormField, 'Contact Name').first,
          'Bruna',
        );
        await t.pump();
      },
    ),
    'notes': (
      const NotesEditPage(),
      (t) async {
        await t.enterText(find.byType(TextField), 'New note');
        await t.pump();
      },
    ),
    'prior': (
      const PriorExperienceEditPage(),
      (t) => typeInto(t, 'Prior dives', '12'),
    ),
  };
  for (final MapEntry(key: path, value: (page, change)) in pages.entries) {
    testWidgets('$path closes on a switch and writes nothing', (tester) async {
      await pumpProfilePage(tester, path: path, page: page, activeDiverId: 'a');
      await change(tester);

      await switchWithoutAsking(tester, 'b');

      expect(find.text('Hub'), findsOneWidget);
      expect(
        await storedDiver('a'),
        alice.copyWith(
          createdAt: (await storedDiver('a'))!.createdAt,
          updatedAt: (await storedDiver('a'))!.updatedAt,
        ),
      );
      expect(await sittings(db), isEmpty);
    });
  }

  testWidgets(
    'a page opened while the active diver still loads fills from the settled '
    'diver',
    (tester) async {
      Completer<void>? gate;
      final router = await pumpProfilePage(
        tester,
        path: 'medical',
        page: const MedicalInfoEditPage(),
        activeDiverId: 'a',
        push: false,
        overrides: [
          currentDiverProvider.overrideWith((ref) async {
            final id = ref.watch(currentDiverIdProvider);
            await gate?.future;
            return id == null ? null : DiverRepository().getDiverById(id);
          }),
        ],
      );
      final container = profileContainer(tester);
      final listening = container.listen(currentDiverProvider, (_, _) {});
      addTearDown(listening.close);
      await tester.pumpAndSettle();

      // Bob becomes active: the validated id settles on him at once, while
      // the active diver still holds Alice as it reloads.
      gate = Completer<void>();
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver('b');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      unawaited(router.push('$diverProfileHub/medical'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Penicillin'), findsNothing);
      expect(find.text('None'), findsOneWidget);
    },
  );

  testWidgets(
    'a page opened before the active diver id is first known waits for it',
    (tester) async {
      Completer<void>? gate;
      final router = await pumpProfilePage(
        tester,
        path: 'medical',
        page: const MedicalInfoEditPage(),
        activeDiverId: 'a',
        push: false,
        overrides: [
          // First worked out when the page opens, and held there.
          validatedCurrentDiverIdProvider.overrideWith((ref) async {
            final id = ref.watch(currentDiverIdProvider);
            await gate?.future;
            return id;
          }),
        ],
      );
      final container = profileContainer(tester);
      final listening = container.listen(currentDiverProvider, (_, _) {});
      addTearDown(listening.close);
      await tester.pumpAndSettle();

      gate = Completer<void>();
      unawaited(router.push('$diverProfileHub/medical'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Bob becomes active before the id is first known; it settles on him.
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver('b');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Penicillin'), findsNothing);
      expect(find.text('None'), findsOneWidget);
    },
  );
}
