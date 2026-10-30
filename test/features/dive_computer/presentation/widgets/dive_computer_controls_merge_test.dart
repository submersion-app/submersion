import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_controls.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_merge_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

DiveComputer _computer({
  required String id,
  required String name,
  String? serialNumber = '3101949313',
  int diveCount = 0,
}) {
  return DiveComputer(
    id: id,
    name: name,
    diverId: 'diver-1',
    manufacturer: 'Shearwater',
    model: 'Petrel 3',
    serialNumber: serialNumber,
    connectionType: 'bluetooth',
    diveCount: diveCount,
    equipmentId: 'gear-$id',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakeMergeRepository implements DiveComputerMergeRepository {
  @override
  Future<int> countAffectedDives({
    required String survivorId,
    required List<String> duplicateIds,
  }) async => 2;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _CapturingNotifier extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _CapturingNotifier() : super(const AsyncValue.data([]));

  String? survivorId;
  List<String>? duplicateIds;

  @override
  Future<DiveComputerMergeResult> merge({
    required String survivorId,
    required List<String> duplicateIds,
  }) async {
    this.survivorId = survivorId;
    this.duplicateIds = duplicateIds;
    return DiveComputerMergeResult(
      survivorId: survivorId,
      mergedComputerIds: duplicateIds,
      movedDiveCount: 2,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _CapturingNotifier notifier;

  setUp(() {
    notifier = _CapturingNotifier();
  });

  /// Routes the detail page for every computer in [all] so a merge that
  /// keeps another record can land on that record's page.
  Future<void> pumpDetail(
    WidgetTester tester, {
    required DiveComputer computer,
    required List<DiveComputer> all,
  }) async {
    final router = GoRouter(
      initialLocation: '/dive-computers/${computer.id}',
      routes: [
        GoRoute(
          path: '/equipment/:id',
          builder: (context, state) =>
              Scaffold(body: Text('ITEM ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/dive-computers/:id',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: DiveComputerControls(
                computerId: state.pathParameters['id']!,
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          diveComputerNotifierProvider.overrideWith((ref) => notifier),
          diveComputerMergeRepositoryProvider.overrideWithValue(
            _FakeMergeRepository(),
          ),
          allDiveComputersProvider.overrideWith((ref) async => all),
          for (final c in all)
            diveComputerByIdProvider(c.id).overrideWith((ref) async => c),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('DiveComputerControls duplicate banner', () {
    testWidgets('names the record that shares this serial number', (
      tester,
    ) async {
      final petrel = _computer(id: 'a', name: 'Petrel 3', diveCount: 21);
      final ssss = _computer(id: 'b', name: 'ssss', diveCount: 2);

      await pumpDetail(tester, computer: petrel, all: [petrel, ssss]);

      expect(find.byKey(const ValueKey('duplicate_banner')), findsOneWidget);
      expect(
        find.textContaining('ssss reports the same serial'),
        findsOneWidget,
      );
    });

    testWidgets('counts the records instead of listing names', (tester) async {
      // The singular message reads "{name} reports...", so joining two names
      // into it would render "ssss, ipad reports the same serial number".
      final petrel = _computer(id: 'a', name: 'Petrel 3', diveCount: 21);
      final ssss = _computer(id: 'b', name: 'ssss', diveCount: 2);
      final ipad = _computer(id: 'c', name: 'ipad', diveCount: 1);

      await pumpDetail(tester, computer: petrel, all: [petrel, ssss, ipad]);

      expect(find.byKey(const ValueKey('duplicate_banner')), findsOneWidget);
      expect(
        find.textContaining('2 other saved records report the same serial'),
        findsOneWidget,
      );
      expect(find.textContaining('ssss, ipad'), findsNothing);
    });

    testWidgets('stays hidden when no other record matches', (tester) async {
      final petrel = _computer(id: 'a', name: 'Petrel 3');
      final other = _computer(id: 'b', name: 'Perdix', serialNumber: '7');

      await pumpDetail(tester, computer: petrel, all: [petrel, other]);

      expect(find.byKey(const ValueKey('duplicate_banner')), findsNothing);
    });

    testWidgets('its Merge button opens the sheet with both records', (
      tester,
    ) async {
      final petrel = _computer(id: 'a', name: 'Petrel 3', diveCount: 21);
      final ssss = _computer(id: 'b', name: 'ssss', diveCount: 2);

      await pumpDetail(tester, computer: petrel, all: [petrel, ssss]);
      await tester.tap(find.byKey(const ValueKey('duplicate_banner_merge')));
      await tester.pumpAndSettle();

      expect(find.text('Merge Dive Computers'), findsOneWidget);
      expect(find.byKey(const ValueKey('merge_keep_a')), findsOneWidget);
      expect(find.byKey(const ValueKey('merge_keep_b')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('merge_confirm')));
      await tester.pumpAndSettle();

      expect(notifier.survivorId, 'a');
      expect(notifier.duplicateIds, ['b']);
      expect(find.text('1 record merged into Petrel 3'), findsOneWidget);
    });
  });

  group('DiveComputerControls merge action', () {
    testWidgets('lists the other computers with same-serial ones flagged', (
      tester,
    ) async {
      final petrel = _computer(id: 'a', name: 'Petrel 3');
      final ssss = _computer(id: 'b', name: 'ssss');
      final perdix = _computer(id: 'c', name: 'Perdix', serialNumber: '7');

      await pumpDetail(tester, computer: petrel, all: [perdix, petrel, ssss]);
      await tester.tap(find.byKey(const ValueKey('dive_computer_merge')));
      await tester.pumpAndSettle();

      expect(find.text('Merge with'), findsOneWidget);
      expect(find.byKey(const ValueKey('merge_pick_b')), findsOneWidget);
      expect(find.byKey(const ValueKey('merge_pick_c')), findsOneWidget);
      expect(find.byKey(const ValueKey('merge_pick_a')), findsNothing);
      expect(find.text('Same serial number'), findsOneWidget);
    });

    testWidgets('explains when there is nothing to merge with', (tester) async {
      final petrel = _computer(id: 'a', name: 'Petrel 3');

      await pumpDetail(tester, computer: petrel, all: [petrel]);
      await tester.tap(find.byKey(const ValueKey('dive_computer_merge')));
      await tester.pumpAndSettle();

      expect(
        find.text('There are no other computers to merge with.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'moves to the surviving record\'s item when this one is folded in',
      (tester) async {
        final petrel = _computer(id: 'a', name: 'Petrel 3', diveCount: 2);
        final ssss = _computer(id: 'b', name: 'ssss', diveCount: 21);

        await pumpDetail(tester, computer: petrel, all: [petrel, ssss]);
        await tester.tap(find.byKey(const ValueKey('dive_computer_merge')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('merge_pick_b')));
        await tester.pumpAndSettle();

        // ssss has more dives, so it is the default survivor.
        await tester.tap(find.byKey(const ValueKey('merge_confirm')));
        await tester.pumpAndSettle();

        expect(notifier.survivorId, 'b');
        expect(notifier.duplicateIds, ['a']);
        // The survivor's Equipment item is the page now (#3676).
        expect(find.text('ITEM gear-b'), findsOneWidget);
      },
    );
  });
}
