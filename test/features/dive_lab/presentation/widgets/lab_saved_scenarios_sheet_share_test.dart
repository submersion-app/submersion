import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/data/repositories/dive_scenario_repository.dart';
import 'package:submersion/features/dive_lab/data/services/scenario_file_codec.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_snapshot.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/lab_share.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/scenario_outcome_provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_saved_scenarios_sheet.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';
import '../../domain/support/synthetic_dives.dart';

class _Recorder extends LabShareActions {
  _Recorder(this.fileToPick);
  final String? fileToPick;
  final pdfs = <List<int>>[];
  final files = <String>[];
  @override
  Future<void> sharePdf(List<int> bytes, String fileName) async =>
      pdfs.add(bytes);
  @override
  Future<void> shareFile(String content, String fileName) async =>
      files.add(content);
  @override
  Future<void> shareImage(List<int> pngBytes, String fileName) async {}
  @override
  Future<String?> pickScenarioFile() async => fileToPick;
}

LabRequestInputs _inputs(Dive dive) {
  final d = squareDive();
  final profile = [
    for (var i = 0; i < d.depths.length; i++)
      DiveProfilePoint(timestamp: d.timestamps[i], depth: d.depths[i]),
  ];
  return LabRequestInputs(
    dive: dive.copyWith(tanks: d.tanks, profile: profile),
    profile: profile,
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

class _Host extends StatelessWidget {
  const _Host(this.diveId);
  final String diveId;
  @override
  Widget build(BuildContext context) => Center(
    child: ElevatedButton(
      onPressed: () => showLabSavedScenariosSheet(context, diveId: diveId),
      child: const Text('open'),
    ),
  );
}

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  testWidgets('import, select + share PDF, and share file', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final dive = await DiveRepository().createDive(
      Dive(id: 'dive-1', diveNumber: 7, dateTime: DateTime(2026, 8, 1)),
    );
    final inputs = _inputs(dive);
    final incoming = scenarioToSublabJson(
      scenario: DiveScenario(
        id: 'remote',
        diveId: dive.id,
        name: 'From instructor',
        branchSeconds: 900,
        mode: ScenarioMode.replan,
        interventions: const [AscendNowIntervention()],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      snapshot: DiveSnapshot.fromDive(
        dive: inputs.dive,
        profile: inputs.profile,
        gasSwitches: inputs.gasSwitches,
        tankPressures: inputs.tankPressures,
      ),
    );
    final recorder = _Recorder(incoming);
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          labRequestInputsProvider(dive.id).overrideWith((ref) async => inputs),
          scenarioEngineRunnerProvider.overrideWithValue(
            (request) async => const ScenarioEngine().run(request),
          ),
          labShareActionsProvider.overrideWithValue(recorder),
        ],
        locale: const Locale('en'),
        child: _Host(dive.id),
      ),
    );

    // Import the shared file: it attaches to the existing dive.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.file_open_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('Imported "From instructor"'), findsOneWidget);
    expect(
      (await DiveScenarioRepository().getScenariosForDive(dive.id)).single.name,
      'From instructor',
    );
    await tester.pumpAndSettle();
    expect(find.text('From instructor'), findsOneWidget);

    // Share as file from the tile menu.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share scenario file'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('Sharing failed'), findsNothing);
    expect(recorder.files, hasLength(1));
    expect(jsonDecode(recorder.files.single)['format'], sublabFormat);

    // Select and share as PDF.
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    // PDF generation loads fonts over real async I/O, which FakeAsync would
    // never complete: drive this step with real time.
    await tester.runAsync(() async {
      await tester.tap(find.text('Share selected as PDF'));
      for (var i = 0; i < 50 && recorder.pdfs.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    expect(find.textContaining('Sharing failed'), findsNothing);
    expect(recorder.pdfs, hasLength(1));
    expect(String.fromCharCodes(recorder.pdfs.single.take(4)), '%PDF');
  });
}
