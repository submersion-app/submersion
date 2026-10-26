import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_merge_sheet.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_merge_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';

import '../../../../helpers/test_app.dart';

DiveComputer _computer({
  required String id,
  required String name,
  String? serialNumber = '3101949313',
  int diveCount = 0,
  bool isFavorite = false,
}) {
  return DiveComputer(
    id: id,
    name: name,
    manufacturer: 'Shearwater',
    model: 'Petrel 3',
    serialNumber: serialNumber,
    diveCount: diveCount,
    isFavorite: isFavorite,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

/// Stands in for the database-backed count.
class _FakeMergeRepository implements DiveComputerMergeRepository {
  final requested = <List<String>>[];
  final requestedSurvivors = <String>[];

  @override
  Future<int> countAffectedDives({
    required String survivorId,
    required List<String> duplicateIds,
  }) async {
    requestedSurvivors.add(survivorId);
    requested.add(duplicateIds);
    return 5;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Records the merge the sheet asked for, or fails it on demand.
class _CapturingNotifier extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _CapturingNotifier({this.failWith}) : super(const AsyncValue.data([]));

  final Object? failWith;
  String? survivorId;
  List<String>? duplicateIds;

  @override
  Future<DiveComputerMergeResult> merge({
    required String survivorId,
    required List<String> duplicateIds,
  }) async {
    this.survivorId = survivorId;
    this.duplicateIds = duplicateIds;
    if (failWith != null) throw failWith!;
    return DiveComputerMergeResult(
      survivorId: survivorId,
      mergedComputerIds: duplicateIds,
      movedDiveCount: 5,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Hosts a button that opens the sheet so the popped result can be captured.
class _Host extends StatefulWidget {
  const _Host({required this.computers});

  final List<DiveComputer> computers;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  DiveComputerMergeResult? result;
  bool dismissed = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      key: const ValueKey('open'),
      onPressed: () async {
        final r = await DiveComputerMergeSheet.show(context, widget.computers);
        setState(() {
          result = r;
          dismissed = r == null;
        });
      },
      child: const Text('open'),
    );
  }
}

void main() {
  late _FakeMergeRepository mergeRepository;
  late _CapturingNotifier notifier;

  setUp(() {
    mergeRepository = _FakeMergeRepository();
    notifier = _CapturingNotifier();
  });

  Future<_HostState> pumpSheet(
    WidgetTester tester,
    List<DiveComputer> computers, {
    _CapturingNotifier? customNotifier,
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          diveComputerMergeRepositoryProvider.overrideWithValue(
            mergeRepository,
          ),
          diveComputerNotifierProvider.overrideWith(
            (ref) => customNotifier ?? notifier,
          ),
        ],
        child: _Host(computers: computers),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    return tester.state<_HostState>(find.byType(_Host));
  }

  group('DiveComputerMergeSheet', () {
    testWidgets('preselects the favorite record and shows the dive count', (
      tester,
    ) async {
      await pumpSheet(tester, [
        _computer(id: 'a', name: 'Petrel 3', diveCount: 21),
        _computer(id: 'b', name: 'ssss', diveCount: 2, isFavorite: true),
      ]);

      expect(find.text('Merge Dive Computers'), findsOneWidget);
      final favorite = tester.widget<RadioListTile<String>>(
        find.byKey(const ValueKey('merge_keep_b')),
      );
      expect(favorite.value, 'b');
      expect(
        find.text('5 dives will move to the record you keep.'),
        findsOneWidget,
      );
      // The count is for the records that will be folded in, not the survivor,
      // and the survivor goes with it: it decides which gear links move.
      expect(mergeRepository.requested.last, ['a']);
      expect(mergeRepository.requestedSurvivors.last, 'b');
      expect(
        find.text('Shearwater Petrel 3 · Serial 3101949313 · 21 dives'),
        findsOneWidget,
      );
    });

    testWidgets("says the other records' Equipment items are folded into "
        'this one (#3676)', (tester) async {
      await pumpSheet(tester, [
        _computer(id: 'a', name: 'Petrel 3'),
        _computer(id: 'b', name: 'ssss'),
      ]);

      expect(
        find.textContaining('Equipment item is folded into this one'),
        findsOneWidget,
      );
    });

    testWidgets('hides the serial warning when every serial agrees', (
      tester,
    ) async {
      await pumpSheet(tester, [
        _computer(id: 'a', name: 'Petrel 3'),
        _computer(id: 'b', name: 'ssss'),
      ]);

      expect(find.byKey(const ValueKey('merge_serial_warning')), findsNothing);
    });

    testWidgets('warns when the records report different serial numbers', (
      tester,
    ) async {
      await pumpSheet(tester, [
        _computer(id: 'a', name: 'Petrel 3'),
        _computer(id: 'b', name: 'Other', serialNumber: '7'),
      ]);

      expect(
        find.byKey(const ValueKey('merge_serial_warning')),
        findsOneWidget,
      );
      expect(find.textContaining('different serial numbers'), findsOneWidget);
    });

    testWidgets('merges into the default survivor and pops the result', (
      tester,
    ) async {
      final host = await pumpSheet(tester, [
        _computer(id: 'a', name: 'Petrel 3', diveCount: 21),
        _computer(id: 'b', name: 'ssss', diveCount: 2),
        _computer(id: 'c', name: 'third'),
      ]);

      await tester.tap(find.byKey(const ValueKey('merge_confirm')));
      await tester.pumpAndSettle();

      expect(notifier.survivorId, 'a');
      expect(notifier.duplicateIds, ['b', 'c']);
      expect(host.result?.survivorId, 'a');
      expect(host.result?.mergedComputerIds, ['b', 'c']);
      expect(find.text('Merge Dive Computers'), findsNothing);
    });

    testWidgets('lets the user keep a different record', (tester) async {
      await pumpSheet(tester, [
        _computer(id: 'a', name: 'Petrel 3', diveCount: 21),
        _computer(id: 'b', name: 'ssss', diveCount: 2),
      ]);

      await tester.tap(find.byKey(const ValueKey('merge_keep_b')));
      await tester.pumpAndSettle();
      expect(mergeRepository.requested.last, ['a']);
      expect(mergeRepository.requestedSurvivors.last, 'b');

      await tester.tap(find.byKey(const ValueKey('merge_confirm')));
      await tester.pumpAndSettle();

      expect(notifier.survivorId, 'b');
      expect(notifier.duplicateIds, ['a']);
    });

    testWidgets('cancel dismisses without merging', (tester) async {
      final host = await pumpSheet(tester, [
        _computer(id: 'a', name: 'Petrel 3'),
        _computer(id: 'b', name: 'ssss'),
      ]);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(host.dismissed, isTrue);
      expect(notifier.survivorId, isNull);
    });

    testWidgets('reports a failed merge and keeps the sheet open', (
      tester,
    ) async {
      final failing = _CapturingNotifier(failWith: StateError('boom'));
      await pumpSheet(tester, [
        _computer(id: 'a', name: 'Petrel 3'),
        _computer(id: 'b', name: 'ssss'),
      ], customNotifier: failing);

      await tester.tap(find.byKey(const ValueKey('merge_confirm')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not merge computers'), findsOneWidget);
      expect(find.text('Merge Dive Computers'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('merge_confirm')),
      );
      expect(button.onPressed, isNotNull);
    });
  });
}
