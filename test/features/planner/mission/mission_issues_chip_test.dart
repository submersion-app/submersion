import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/mission_outcome_provider.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<MissionOutcome> _syncRunner(
  domain.DivePlan plan,
  DpvMission mission,
  PlanEngineConfig config,
) async => const MissionEngine().compute(plan: plan, mission: mission);

void main() {
  testWidgets('the chip counts blocking mission issues and hides without', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          missionEngineRunnerProvider.overrideWithValue(_syncRunner),
        ],
        child: MissionIssuesChip(onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Mission:'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MissionIssuesChip)),
    );
    // The starter: an empty leg and a scooter with no numbers.
    container
        .read(divePlanNotifierProvider.notifier)
        .enableMission(
          MissionEdits.starter(
            legId: 'L1',
            memberId: 'a',
            memberName: 'Sam',
            sacBottom: 15,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.textContaining('Mission:'), findsOneWidget);
  });

  testWidgets('the chip counts the known issues while the mission computes', (
    tester,
  ) async {
    // A computation that never lands, as a slow isolate or a failed one.
    final pending = Completer<MissionOutcome>();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          missionEngineRunnerProvider.overrideWithValue(
            (plan, mission, config) => pending.future,
          ),
        ],
        child: MissionIssuesChip(onTap: () {}),
      ),
    );
    ProviderScope.containerOf(tester.element(find.byType(MissionIssuesChip)))
        .read(divePlanNotifierProvider.notifier)
        .enableMission(
          MissionEdits.starter(
            legId: 'L1',
            memberId: 'a',
            memberName: 'Sam',
            sacBottom: 15,
          ),
        );
    await tester.pump();
    expect(find.textContaining('Mission:'), findsOneWidget);
  });
}
