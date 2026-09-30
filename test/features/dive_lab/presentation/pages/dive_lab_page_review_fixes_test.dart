import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/data/repositories/dive_scenario_repository.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/lab_share.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_lab/presentation/providers/dive_scenario_providers.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/scenario_outcome_provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../domain/support/synthetic_dives.dart';

class _Recorder extends LabShareActions {
  final pdfs = <List<int>>[];
  @override
  Future<void> sharePdf(List<int> bytes, String fileName) async =>
      pdfs.add(bytes);
  @override
  Future<void> shareFile(String content, String fileName) async {}
  @override
  Future<void> shareImage(List<int> pngBytes, String fileName) async {}
  @override
  Future<String?> pickScenarioFile() async => null;
}

/// A repository whose saved scenario has gone (deleted elsewhere, synced).
class _Gone implements DiveScenarioRepository {
  @override
  Future<DiveScenario?> getScenario(String id) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LabRequestInputs _inputs() {
  final d = squareDive(depth: 40, bottomMinutes: 25);
  return LabRequestInputs(
    dive: Dive(id: 'd', diveNumber: 3, dateTime: DateTime(2026, 9, 26)),
    profile: [
      for (var i = 0; i < d.depths.length; i++)
        DiveProfilePoint(timestamp: d.timestamps[i], depth: d.depths[i]),
    ],
    depths: d.depths,
    timestamps: d.timestamps,
    diveMode: DiveMode.oc,
    tanks: d.tanks,
    gasSwitches: d.switches,
    tankPressures: d.tankPressures,
    startCns: 0,
    startOtu: 0,
    settings: const ScenarioSettings(),
  );
}

List<Object> _overrides({
  _Recorder? recorder,
  Future<void> Function()? beforeRun,
}) => [
  settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
  labRequestInputsProvider('d').overrideWith((ref) async => _inputs()),
  labDefaultBranchProvider('d').overrideWith((ref) async => 900),
  scenarioEngineRunnerProvider.overrideWithValue((request) async {
    await beforeRun?.call();
    return const ScenarioEngine().run(request);
  }),
  diveScenarioRepositoryProvider.overrideWithValue(_Gone()),
  if (recorder != null) labShareActionsProvider.overrideWithValue(recorder),
];

void main() {
  testWidgets('opening a saved scenario that is gone starts a fresh draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: _overrides(),
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDiveLab(context, 'd', scenarioId: 'gone'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.text('open')),
    );
    container
        .read(labDraftProvider('d').notifier)
        .loadScenario(
          DiveScenario(
            id: 'other',
            diveId: 'd',
            name: 'A different saved scenario',
            branchSeconds: 1200,
            mode: ScenarioMode.replan,
            interventions: const [AscendNowIntervention()],
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final draft = container.read(labDraftProvider('d'));
    expect(draft.scenarioId, isNull);
    expect(draft.interventions, isEmpty);
    expect(draft.branchSeconds, 900);
  });

  testWidgets('Share PDF slate during a recompute shares the new outcome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final recorder = _Recorder();
    var gate = Completer<void>()..complete();
    await tester.pumpWidget(
      testApp(
        overrides: _overrides(recorder: recorder, beforeRun: () => gate.future),
        locale: const Locale('en'),
        child: const DiveLabPage(diveId: 'd'),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveLabPage)),
    );
    // Hold the next engine run so the recompute is still pending at the tap.
    gate = Completer<void>();
    container
        .read(labDraftProvider('d').notifier)
        .addIntervention(const AscendNowIntervention());
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(container.read(scenarioOutcomeProvider('d')).isLoading, isTrue);
    await tester.tap(find.byTooltip('More'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // PDF generation loads fonts over real async I/O: drive it in real time.
    await tester.runAsync(() async {
      await tester.tap(find.text('Share PDF slate'));
      await tester.pump(const Duration(milliseconds: 100));
      gate.complete();
      for (var i = 0; i < 60 && recorder.pdfs.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    expect(recorder.pdfs, hasLength(1));
    expect(String.fromCharCodes(recorder.pdfs.single.take(4)), '%PDF');
  });
}
