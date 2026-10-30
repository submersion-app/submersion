import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/divers/data/repositories/diver_merge_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/misplaced_logbook.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/misplaced_logbook_providers.dart';
import 'package:submersion/features/divers/presentation/widgets/misplaced_logbook_banner.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _FakeMergeRepository implements DiverMergeRepository {
  final merges = <({String keeperId, String duplicateId})>[];
  final undone = <DiverMergeSnapshot>[];
  Object? failWith;
  Object? failUndoWith;
  Completer<void>? hold;

  @override
  Future<DiverMergeSnapshot> mergeDivers({
    required String keeperId,
    required String duplicateId,
  }) async {
    final error = failWith;
    if (error != null) throw error;
    await hold?.future;
    merges.add((keeperId: keeperId, duplicateId: duplicateId));
    return DiverMergeSnapshot(
      keeperId: keeperId,
      duplicateId: duplicateId,
      duplicateDiver: const {},
      repointedRows: const [],
      deletedSingletonRows: const [],
    );
  }

  @override
  Future<void> undoMerge(DiverMergeSnapshot snapshot) async {
    final error = failUndoWith;
    if (error != null) throw error;
    undone.add(snapshot);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDiverRepository implements DiverRepository {
  Map<String, int> counts = {'main': 212};

  @override
  Future<Map<String, int>> getDiveCountsByDiver() async => counts;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Diver _diver(String id, String name) => Diver(
  id: id,
  name: name,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final _active = _diver('empty', 'iPhone Diver');
final _target = _diver('main', 'Dave');

void main() {
  late SharedPreferences prefs;
  late MockCurrentDiverIdNotifier currentDiver;
  late _FakeMergeRepository mergeRepo;
  late _FakeDiverRepository diverRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    currentDiver = MockCurrentDiverIdNotifier();
    await currentDiver.setCurrentDiver(_active.id);
    mergeRepo = _FakeMergeRepository();
    diverRepo = _FakeDiverRepository();
  });

  Future<void> pumpBanner(
    WidgetTester tester, {
    MisplacedLogbook? found,
    bool canMerge = true,
  }) async {
    final value =
        found ??
        MisplacedLogbook(
          active: _active,
          target: _target,
          targetDiveCount: 212,
          canMerge: canMerge,
        );
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentDiverIdProvider.overrideWith((ref) => currentDiver),
          diverMergeRepositoryProvider.overrideWithValue(mergeRepo),
          diverRepositoryProvider.overrideWithValue(diverRepo),
          misplacedLogbookProvider.overrideWith((ref) async => value),
        ],
        child: const MisplacedLogbookBanner(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders nothing when no logbook is misplaced', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          misplacedLogbookProvider.overrideWith((ref) async => null),
        ],
        child: const MisplacedLogbookBanner(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your dives are in another diver profile'), findsNothing);
  });

  testWidgets('names both profiles and the dive count', (tester) async {
    await pumpBanner(tester);

    expect(find.text('Your dives are in another diver profile'), findsOne);
    expect(
      find.text(
        '"Dave" has 212 dives. This device is showing "iPhone Diver", which '
        'has none. This can happen when a device creates its own profile '
        'before its first sync.',
      ),
      findsOne,
    );
    expect(find.text('Switch'), findsOne);
    expect(find.text('Merge'), findsOne);
    expect(find.text('Keep both'), findsOne);
  });

  testWidgets('offers no merge when several profiles hold dives', (
    tester,
  ) async {
    await pumpBanner(tester, canMerge: false);

    expect(find.text('Switch'), findsOne);
    expect(find.text('Merge'), findsNothing);
    expect(find.text('Keep both'), findsOne);
  });

  testWidgets('Switch makes the profile holding the dives active', (
    tester,
  ) async {
    await pumpBanner(tester);

    await tester.tap(find.text('Switch'));
    await tester.pumpAndSettle();

    expect(currentDiver.state, _target.id);
    expect(mergeRepo.merges, isEmpty);
  });

  testWidgets('Keep both remembers the pair on this device', (tester) async {
    await pumpBanner(tester);

    await tester.tap(find.text('Keep both'));
    await tester.pumpAndSettle();

    expect(prefs.getStringList(misplacedLogbookKeptBothKey), [
      misplacedLogbookPairKey(_active.id, _target.id),
    ]);
    expect(currentDiver.state, _active.id);
  });

  testWidgets('Merge asks first and does nothing when cancelled', (
    tester,
  ) async {
    await pumpBanner(tester);

    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();
    expect(find.text('Merge diver profiles?'), findsOne);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(mergeRepo.merges, isEmpty);
    expect(currentDiver.state, _active.id);
  });

  testWidgets('Merge moves the empty profile into the logbook and can be '
      'undone', (tester) async {
    await pumpBanner(tester);

    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Merge'),
      ),
    );
    await tester.pumpAndSettle();

    expect(mergeRepo.merges, [(keeperId: 'main', duplicateId: 'empty')]);
    expect(currentDiver.state, _target.id);
    expect(find.text('Merged into Dave'), findsOne);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(mergeRepo.undone, hasLength(1));
    expect(currentDiver.state, _active.id);
  });

  testWidgets('a failed merge says so and keeps the active profile', (
    tester,
  ) async {
    mergeRepo.failWith = StateError('database is locked');
    await pumpBanner(tester);

    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Merge'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('database is locked'), findsOne);
    expect(currentDiver.state, _active.id);
  });

  Future<void> confirmMerge(WidgetTester tester) async {
    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Merge'),
      ),
    );
  }

  testWidgets('a failed undo says so and keeps the kept profile active', (
    tester,
  ) async {
    mergeRepo.failUndoWith = StateError('undo blocked');
    await pumpBanner(tester);
    await confirmMerge(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Undo failed: Bad state: undo blocked'), findsOne);
    expect(currentDiver.state, _target.id);
  });

  testWidgets('the actions are disabled while a merge runs', (tester) async {
    final hold = Completer<void>();
    mergeRepo.hold = hold;
    await pumpBanner(tester);
    await confirmMerge(tester);
    await tester.pumpAndSettle();

    ButtonStyleButton button(String label) => tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button('Merge').onPressed, isNull);
    expect(button('Switch').onPressed, isNull);
    expect(button('Keep both').onPressed, isNull);

    hold.complete();
    await tester.pumpAndSettle();

    expect(mergeRepo.merges, hasLength(1));
    expect(button('Merge').onPressed, isNotNull);
  });

  testWidgets('Merge does not run when a second profile gained dives while '
      'the dialog was open', (tester) async {
    await pumpBanner(tester);
    diverRepo.counts = {'main': 212, 'spouse': 30};

    await confirmMerge(tester);
    await tester.pumpAndSettle();

    expect(mergeRepo.merges, isEmpty);
    expect(currentDiver.state, _active.id);
  });

  testWidgets('keeps showing while the provider reloads, with the actions '
      'locked until the new answer lands', (tester) async {
    final reload = StateProvider<int>((ref) => 0);
    final hold = Completer<void>();
    final value = MisplacedLogbook(
      active: _active,
      target: _target,
      targetDiveCount: 212,
      canMerge: true,
    );
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentDiverIdProvider.overrideWith((ref) => currentDiver),
          diverMergeRepositoryProvider.overrideWithValue(mergeRepo),
          diverRepositoryProvider.overrideWithValue(diverRepo),
          misplacedLogbookProvider.overrideWith((ref) async {
            if (ref.watch(reload) > 0) await hold.future;
            return value;
          }),
        ],
        child: const MisplacedLogbookBanner(),
      ),
    );
    await tester.pumpAndSettle();

    ProviderScope.containerOf(
      tester.element(find.byType(MisplacedLogbookBanner)),
    ).read(reload.notifier).state++;
    await tester.pump();

    ButtonStyleButton button(String label) => tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(find.text('Your dives are in another diver profile'), findsOne);
    expect(button('Merge').onPressed, isNull);
    expect(button('Keep both').onPressed, isNull);

    hold.complete();
    await tester.pumpAndSettle();

    expect(button('Merge').onPressed, isNotNull);
  });
}
