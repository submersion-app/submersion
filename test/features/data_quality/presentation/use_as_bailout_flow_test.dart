import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/data/services/quality_repair_executor.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/repairs/quality_repair_action.dart';
import 'package:submersion/features/data_quality/presentation/widgets/use_as_bailout_flow.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #3307: the inbox's "Use as bailout" glue. It confirms, hands the
/// executor what the diver chose, and reports the registration truthfully.
class _FakeDiveRepository extends Fake implements DiveRepository {
  _FakeDiveRepository(this.dive);
  final Dive? dive;

  @override
  Future<Dive?> getDiveById(String id) async => dive;
}

class _FakeExecutor extends Fake implements QualityRepairExecutor {
  _FakeExecutor({this.registered = true, this.mixesKept = 0});
  final bool registered;
  final int mixesKept;
  final calls = <Map<String, Object?>>[];

  @override
  Future<
    ({RepairResult result, int mixesKept, bool registered, TankRole? role})
  >
  useAsBailout({
    required String diveId,
    required String tankId,
    required String ocTankId,
    required String findingId,
    required bool registerTransmitter,
    String? serial,
    String? label,
    String? diverId,
  }) async {
    calls.add({
      'diveId': diveId,
      'tankId': tankId,
      'ocTankId': ocTankId,
      'findingId': findingId,
      'register': registerTransmitter,
      'serial': serial,
      'label': label,
      'diverId': diverId,
    });
    return (
      result: const RepairResult.applied(),
      mixesKept: mixesKept,
      registered: registered,
      role: TankRole.bailout,
    );
  }
}

void main() {
  final dive = Dive(
    id: 'd1',
    diverId: 'diver-1',
    dateTime: DateTime.utc(2026, 7, 1, 10),
    diveMode: DiveMode.ccr,
    tanks: const [
      DiveTank(id: 'dil', order: 0, role: TankRole.diluent),
      DiveTank(
        id: 'tx',
        name: 'OC',
        order: 4,
        role: TankRole.oxygenSupply,
        roleSource: TankRoleSource.transmitterName,
        gasMix: GasMix(o2: 100, he: 0),
        transmitterSerial: '180777',
        sourceTankIndex: 4,
      ),
      DiveTank(
        id: 'oc',
        order: 7,
        role: TankRole.bailout,
        gasMix: GasMix(o2: 18, he: 45),
        sourceTankIndex: 7,
      ),
    ],
  );
  final finding = QualityFinding(
    id: 'f1',
    diveId: 'd1',
    detectorId: 'transmitter_role',
    detectorVersion: 1,
    category: QualityCategory.tank,
    severity: QualitySeverity.warning,
    status: QualityStatus.open,
    createdAt: DateTime.utc(2026, 7, 17),
    updatedAt: DateTime.utc(2026, 7, 17),
  );
  const action = UseAsBailoutRepair(diveId: 'd1', tankId: 'tx', ocTankId: 'oc');

  late AppLocalizations l10n;
  String? lastNote;
  var ran = false;

  Future<void> start(
    WidgetTester tester, {
    required _FakeExecutor executor,
    Dive? diveToLoad,
    bool useDive = true,
  }) async {
    lastNote = null;
    ran = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return TextButton(
              onPressed: () => runUseAsBailoutRepair(
                context,
                finding: finding,
                action: action,
                executor: executor,
                hasPressureSeries: (_, _) async => false,
                diveRepository: _FakeDiveRepository(
                  useDive ? (diveToLoad ?? dive) : null,
                ),
                withUndo: (run, {note}) async {
                  await run();
                  ran = true;
                  lastNote = note?.call();
                },
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('confirming hands the executor the tank, its transmitter and '
      'the diver', (tester) async {
    final executor = _FakeExecutor(mixesKept: 2);
    await start(tester, executor: executor);

    // The dive page numbers tanks by position: the transmitter is Tank 2.
    expect(
      find.text(
        'Removes the duplicate Bailout cylinder (switches move to Tank 2)',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Use as bailout'));
    await tester.pumpAndSettle();

    expect(executor.calls.single, {
      'diveId': 'd1',
      'tankId': 'tx',
      'ocTankId': 'oc',
      'findingId': 'f1',
      'register': true,
      'serial': '180777',
      'label': 'OC',
      'diverId': 'diver-1',
    });
    expect(ran, isTrue);
    expect(
      lastNote,
      '${l10n.dataQuality_useAsBailout_registered('Bailout')} '
      '${l10n.dataQuality_useAsBailout_mixesKept(2)}',
    );
  });

  testWidgets('no registration note when nothing was registered', (
    tester,
  ) async {
    final executor = _FakeExecutor(registered: false);
    await start(tester, executor: executor);
    await tester.tap(find.text('Use as bailout'));
    await tester.pumpAndSettle();

    expect(ran, isTrue);
    expect(lastNote, isNull);
  });

  testWidgets('cancelling runs nothing', (tester) async {
    final executor = _FakeExecutor();
    await start(tester, executor: executor);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(executor.calls, isEmpty);
    expect(ran, isFalse);
  });

  testWidgets('a dive that is gone shows nothing', (tester) async {
    final executor = _FakeExecutor();
    await start(tester, executor: executor, useDive: false);

    expect(find.byType(AlertDialog), findsNothing);
    expect(executor.calls, isEmpty);
  });

  testWidgets('a tank that is gone shows nothing', (tester) async {
    final executor = _FakeExecutor();
    await start(
      tester,
      executor: executor,
      diveToLoad: dive.copyWith(tanks: [dive.tanks.first]),
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(executor.calls, isEmpty);
  });
}
