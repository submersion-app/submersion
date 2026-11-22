import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_slot_matcher.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/features/transmitters/presentation/widgets/transmitter_section.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_key_saved.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/mock_providers.dart';

/// Answers the apply preview with fixed counts and records each key applied;
/// [failApply] makes the write fail, as a closed database would.
class _FakeApplyRepository extends TransmitterRepository {
  _FakeApplyRepository({required this.preview, this.failApply = false});

  final ApplyToExistingResult preview;
  final bool failApply;
  final applied = <String>[];

  @override
  Future<ApplyToExistingResult> previewApplyToExistingDives(
    Transmitter t, {
    Iterable<String> slotTankIds = const [],
  }) async => preview;

  @override
  Future<ApplyToExistingResult> applyToExistingDives(
    Transmitter t, {
    Iterable<String> slotTankIds = const [],
  }) async {
    if (failApply) throw StateError('database closed');
    applied.add(t.id);
    return preview;
  }
}

/// Offers no computer to match by slot; the slot dialog has its own tests
/// (transmitter_apply_dialog_test.dart).
class _NoSlots extends TransmitterSlotMatcher {
  @override
  Future<List<SlotComputer>> computersWithCandidates(Transmitter t) async =>
      const [];
}

/// The key editor, standing in: SAVE KEY pops with [result], as the
/// editor's Save does (issue #4527, phase 4).
class _StandInEditor extends StatelessWidget {
  const _StandInEditor({required this.title, this.result});

  final String title;
  final Object? result;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text(title),
        TextButton(
          onPressed: () => Navigator.of(context).pop(result),
          child: const Text('SAVE KEY'),
        ),
      ],
    ),
  );
}

/// A transmitter's setup lives on its Equipment page (issue #3676).
void main() {
  Transmitter key({
    String id = 'k1',
    bool configured = true,
    String? cylinder,
    double? volume,
  }) => Transmitter(
    id: id,
    transmitterSerial: '4A21F',
    label: 'Back gas tx',
    role: TankRole.stage,
    equipmentId: cylinder,
    volumeL: volume,
    isConfigured: configured,
    transmitterEquipmentId: 'tx-gear',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pump(
    WidgetTester tester,
    List<Transmitter> keys, {
    TransmitterRepository? repository,
    Object? editorResult,
    RecordEditController<EquipmentItem>? item,
    ValueNotifier<bool>? relayout,
    List<Transmitter> Function()? keysNow,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/equipment/tx-gear',
      routes: [
        GoRoute(
          path: '/equipment/cyl',
          builder: (_, _) => const Scaffold(body: Text('CYLINDER PAGE')),
        ),
        GoRoute(
          path: '/equipment/:id',
          builder: (_, s) {
            final card = TransmitterSection(
              equipmentId: s.pathParameters['id']!,
            );
            final section = Scaffold(
              body: SingleChildScrollView(
                // The item page laid out afresh puts the card in a new
                // place: a new element, the old one unmounted.
                child: relayout == null
                    ? card
                    : ValueListenableBuilder<bool>(
                        valueListenable: relayout,
                        builder: (_, moved, _) =>
                            moved ? Column(children: [card]) : card,
                      ),
              ),
            );
            // The item page's sitting, when the test gives it one.
            return item == null
                ? section
                : RecordEditScope<EquipmentItem>(
                    controller: item,
                    child: section,
                  );
          },
          routes: [
            GoRoute(
              path: 'transmitter',
              builder: (_, _) =>
                  _StandInEditor(title: 'ADD KEY', result: editorResult),
              routes: [
                GoRoute(
                  path: ':k',
                  builder: (_, s) => _StandInEditor(
                    title: 'EDIT ${s.pathParameters['k']}',
                    result: editorResult,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          transmittersForEquipmentProvider(
            'tx-gear',
          ).overrideWith((ref) async => keysNow?.call() ?? keys),
          if (repository != null)
            transmitterRepositoryProvider.overrideWithValue(repository),
          transmitterSlotMatcherProvider.overrideWithValue(_NoSlots()),
          equipmentItemProvider('cyl').overrideWith(
            (ref) async => const EquipmentItem(
              id: 'cyl',
              name: 'Blue AL80',
              type: EquipmentType.tank,
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an auto-created transmitter says no cylinder is set up', (
    tester,
  ) async {
    await pump(tester, [key(configured: false)]);

    expect(find.text('No cylinder set up'), findsOneWidget);
    expect(find.text('Transmitter 4A21F'), findsOneWidget);
  });

  testWidgets('a set-up transmitter names its cylinder and role', (
    tester,
  ) async {
    await pump(tester, [key(cylinder: 'cyl')]);

    expect(find.text('No cylinder set up'), findsNothing);
    expect(find.text('Blue AL80'), findsOneWidget);
    expect(find.textContaining('Stage'), findsOneWidget);
  });

  testWidgets('Set up opens the key in the setup editor', (tester) async {
    await pump(tester, [key(configured: false)]);

    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();

    expect(find.text('EDIT k1'), findsOneWidget);
  });

  testWidgets('a hand-added transmitter with no key offers to add one', (
    tester,
  ) async {
    await pump(tester, const []);

    await tester.tap(find.text('Add serial or channel'));
    await tester.pumpAndSettle();

    expect(find.text('ADD KEY'), findsOneWidget);
  });

  testWidgets('tapping a key opens it in the setup editor', (tester) async {
    await pump(tester, [key(id: 'k7', cylinder: 'cyl')]);

    await tester.tap(find.text('Transmitter 4A21F'));
    await tester.pumpAndSettle();

    expect(find.text('EDIT k7'), findsOneWidget);
  });

  testWidgets('the cylinder row opens the cylinder', (tester) async {
    await pump(tester, [key(cylinder: 'cyl')]);

    await tester.tap(find.text('Blue AL80'));
    await tester.pumpAndSettle();

    expect(find.text('CYLINDER PAGE'), findsOneWidget);
  });

  group('Apply to existing dives', () {
    testWidgets('says so when no cylinder carries the transmitter', (
      tester,
    ) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 0, divesUpdated: 0, mixesKept: 0),
      );
      await pump(tester, [key(cylinder: 'cyl')], repository: repo);

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();

      expect(
        find.text("No cylinder needs this transmitter's setup"),
        findsOneWidget,
      );
      expect(repo.applied, isEmpty);
    });

    testWidgets('applies every key once confirmed', (tester) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 2, divesUpdated: 2, mixesKept: 0),
      );
      await pump(tester, [
        key(id: 'k1', cylinder: 'cyl'),
        key(id: 'k2', cylinder: 'cyl'),
      ], repository: repo);

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          '4 cylinders on 4 dives carrying this transmitter need its setup',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(repo.applied, ['k1', 'k2']);
      expect(find.text('Updated 4 cylinders on 4 dives'), findsOneWidget);
    });

    testWidgets('cancelling applies nothing', (tester) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 2, divesUpdated: 2, mixesKept: 0),
      );
      await pump(tester, [key(cylinder: 'cyl')], repository: repo);

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.applied, isEmpty);
    });

    testWidgets('a failed apply says so', (tester) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 2, divesUpdated: 2, mixesKept: 0),
        failApply: true,
      );
      await pump(tester, [key(cylinder: 'cyl')], repository: repo);

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(find.textContaining('database closed'), findsOneWidget);
    });
  });

  // The key editor hands its Save back to the card, whose snackbar offers
  // the card's own Apply (issue #4527, phase 4, plan 2).
  group('after the key editor saves', () {
    const nameField = EditField<EquipmentItem, String>(
      id: 'name',
      cardId: 'details',
      read: _name,
      write: _rename,
    );
    const item = EquipmentItem(
      id: 'tx-gear',
      name: 'Back gas tx',
      type: EquipmentType.transmitter,
    );

    RecordEditController<EquipmentItem> sitting({
      bool unlocked = true,
      bool dirty = false,
    }) {
      final controller = RecordEditController<EquipmentItem>(
        onSave: (_) async {},
      );
      addTearDown(controller.dispose);
      if (unlocked) controller.unlock(item);
      if (dirty) controller.session!.set(nameField, 'Renamed');
      return controller;
    }

    _FakeApplyRepository repoWithDives() => _FakeApplyRepository(
      preview: (tanksUpdated: 2, divesUpdated: 2, mixesKept: 0),
    );

    Future<void> saveFromEditor(WidgetTester tester) async {
      await tester.tap(find.text('Add serial or channel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE KEY'));
      await tester.pumpAndSettle();
    }

    /// Taps the snackbar's Apply, as the diver does: the snackbar goes as
    /// its action runs.
    Future<void> tapSnackApply(WidgetTester tester) => tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Apply to existing dives'),
      ),
    );

    SnackBarAction? snackApply(WidgetTester tester) => tester
        .widgetList<SnackBarAction>(find.byType(SnackBarAction))
        .firstOrNull;

    testWidgets('a first setup saved shows Saved with Apply', (tester) async {
      await pump(
        tester,
        [key(cylinder: 'cyl')],
        repository: repoWithDives(),
        editorResult: const TransmitterKeySaved(offerApply: true),
      );
      await saveFromEditor(tester);

      expect(find.text('Transmitter saved'), findsOneWidget);
      expect(snackApply(tester)?.label, 'Apply to existing dives');
    });

    testWidgets('an edit saved shows Saved with no Apply', (tester) async {
      await pump(
        tester,
        [key(cylinder: 'cyl')],
        repository: repoWithDives(),
        editorResult: const TransmitterKeySaved(offerApply: false),
      );
      await saveFromEditor(tester);

      expect(find.text('Transmitter saved'), findsOneWidget);
      expect(snackApply(tester), isNull);
    });

    testWidgets('Saved still shows when the card was rebuilt meanwhile', (
      tester,
    ) async {
      final relayout = ValueNotifier(false);
      addTearDown(relayout.dispose);
      await pump(
        tester,
        [key(cylinder: 'cyl')],
        repository: repoWithDives(),
        editorResult: const TransmitterKeySaved(offerApply: true),
        relayout: relayout,
      );
      await tester.tap(find.text('Add serial or channel'));
      await tester.pumpAndSettle();
      relayout.value = true;
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE KEY'));
      await tester.pumpAndSettle();

      expect(find.text('Transmitter saved'), findsOneWidget);
    });

    testWidgets('leaving the editor without saving shows nothing', (
      tester,
    ) async {
      await pump(tester, [key(cylinder: 'cyl')], repository: repoWithDives());
      await saveFromEditor(tester);

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('the snackbar Apply shows the counts and asks first', (
      tester,
    ) async {
      final repo = repoWithDives();
      await pump(
        tester,
        [key(id: 'k1', cylinder: 'cyl'), key(id: 'k2', cylinder: 'cyl')],
        repository: repo,
        editorResult: const TransmitterKeySaved(offerApply: true),
      );
      await saveFromEditor(tester);
      await tapSnackApply(tester);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          '4 cylinders on 4 dives carrying this transmitter need its setup',
        ),
        findsOneWidget,
      );
      expect(repo.applied, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(repo.applied, ['k1', 'k2']);
      expect(find.text('Updated 4 cylinders on 4 dives'), findsOneWidget);
    });

    testWidgets('the snackbar Apply works on the keys as they are now', (
      tester,
    ) async {
      final repo = repoWithDives();
      var current = [key(id: 'k1', cylinder: 'cyl')];
      await pump(
        tester,
        current,
        repository: repo,
        editorResult: const TransmitterKeySaved(offerApply: true),
        keysNow: () => current,
      );
      await saveFromEditor(tester);
      // The save added a key; the card's list has not been read again yet.
      current = [...current, key(id: 'k2', cylinder: 'cyl')];
      await tapSnackApply(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(repo.applied, ['k1', 'k2']);
    });

    testWidgets('cancelling the snackbar Apply writes nothing', (tester) async {
      final repo = repoWithDives();
      await pump(
        tester,
        [key(cylinder: 'cyl')],
        repository: repo,
        editorResult: const TransmitterKeySaved(offerApply: true),
      );
      await saveFromEditor(tester);
      await tapSnackApply(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.applied, isEmpty);
    });

    testWidgets('a snackbar Apply that fails says so', (tester) async {
      await pump(
        tester,
        [key(cylinder: 'cyl')],
        repository: _FakeApplyRepository(
          preview: (tanksUpdated: 2, divesUpdated: 2, mixesKept: 0),
          failApply: true,
        ),
        editorResult: const TransmitterKeySaved(offerApply: true),
      );
      await saveFromEditor(tester);
      await tapSnackApply(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(find.textContaining('database closed'), findsOneWidget);
    });

    testWidgets('the snackbar Apply is refused while the item has changes', (
      tester,
    ) async {
      final repo = repoWithDives();
      final controller = sitting();
      await pump(
        tester,
        [key(cylinder: 'cyl')],
        repository: repo,
        editorResult: const TransmitterKeySaved(offerApply: true),
        item: controller,
      );
      await saveFromEditor(tester);
      controller.session!.set(nameField, 'Renamed');
      await tester.pump();
      await tapSnackApply(tester);
      await tester.pumpAndSettle();

      expect(find.text('Save or cancel your changes first'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.applied, isEmpty);
    });

    testWidgets(
      'the snackbar Apply runs through the gate of an unlocked page',
      (tester) async {
        final repo = repoWithDives();
        final controller = sitting();
        await pump(
          tester,
          [key(cylinder: 'cyl')],
          repository: repo,
          editorResult: const TransmitterKeySaved(offerApply: true),
          item: controller,
        );
        await saveFromEditor(tester);
        await tapSnackApply(tester);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(controller.isOperating, isTrue);
        await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
        await tester.pumpAndSettle();
        expect(controller.isOperating, isFalse);
        expect(repo.applied, ['k1']);
      },
    );

    testWidgets('on a locked page the snackbar Apply asks and runs', (
      tester,
    ) async {
      final repo = repoWithDives();
      await pump(
        tester,
        [key(cylinder: 'cyl')],
        repository: repo,
        editorResult: const TransmitterKeySaved(offerApply: true),
        item: sitting(unlocked: false),
      );
      await saveFromEditor(tester);
      await tapSnackApply(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(repo.applied, ['k1']);
    });
  });
}

String _name(EquipmentItem item) => item.name;

EquipmentItem _rename(EquipmentItem item, String name) =>
    item.copyWith(name: name);
