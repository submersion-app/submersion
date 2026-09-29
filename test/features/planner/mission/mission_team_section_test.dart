import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/presentation/panes/plan_setup_accordion.dart';
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

Widget _harness() => testApp(
  overrides: [settingsProvider.overrideWith((ref) => _TestSettingsNotifier())],
  locale: const Locale('en'),
  child: const SingleChildScrollView(child: PlanSetupAccordion()),
);

void main() {
  testWidgets('the DPV team section appears only with a mission', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.text('DPV team'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSetupAccordion)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .enableMission(
          MissionEdits.starter(
            legId: 'L1',
            memberId: 'm1',
            memberName: 'Sam',
            sacBottom: 15,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('DPV team'), findsOneWidget);
  });

  testWidgets('adding a diver adds a card, open water shows walk speed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSetupAccordion)),
    );
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.enableMission(
      MissionEdits.starter(
        legId: 'L1',
        memberId: 'm1',
        memberName: 'Sam',
        sacBottom: 15,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('DPV team'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add diver'));
    await tester.pumpAndSettle();
    expect(
      container.read(divePlanNotifierProvider).mission!.team,
      hasLength(2),
    );

    expect(find.text('Walking speed'), findsNothing);
    await tester.tap(find.text('Open water'));
    await tester.pumpAndSettle();
    expect(
      container.read(divePlanNotifierProvider).mission!.environment,
      MissionEnvironment.openWater,
    );
    expect(find.text('Walking speed'), findsOneWidget);
  });

  testWidgets('the DPV team section fits a 320 pt phone with every field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSetupAccordion)),
    );
    final starter = MissionEdits.starter(
      legId: 'L1',
      memberId: 'm1',
      memberName: 'Alexandria Montgomery-Fitzwilliam',
      sacBottom: 15,
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .enableMission(
          MissionEdits.addMember(
            starter,
            'm2',
            name: 'Sam',
            sacBottom: 18,
          ).copyWith(
            environment: MissionEnvironment.openWater,
            defaultCurrent: const CurrentVector(
              speedMps: 0.2,
              setsTowardDeg: 90,
            ),
            surfaceSwimLimitM: 300,
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.text('DPV team'));
    await tester.pumpAndSettle();
    expect(find.text('Walking speed'), findsOneWidget);
    expect(find.text('Sets toward'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a diver card reads RMV, swim speed and scooter in order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSetupAccordion)),
    );
    final starter = MissionEdits.starter(
      legId: 'L1',
      memberId: 'm1',
      memberName: 'Sam',
      sacBottom: 15,
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .enableMission(
          MissionEdits.updateMember(
            starter,
            const MissionMember(
              id: 'm1',
              order: 0,
              displayName: 'Sam',
              sacBottom: 15,
              swimSpeedMps: 0.5,
              scooter: ScooterSpec(
                name: 'Long-range DPV',
                ratedSpeedMps: 1.2,
                burnTimeSeconds: 150 * 60,
              ),
            ),
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.text('DPV team'));
    await tester.pumpAndSettle();
    expect(find.textContaining('swim 30 m/min'), findsOneWidget);
    expect(
      find.textContaining('Long-range DPV: 72 m/min, 150 min burn'),
      findsOneWidget,
    );
  });
}
