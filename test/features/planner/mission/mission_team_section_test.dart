import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'dart:typed_data';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
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

Widget _harness({List<dynamic> overrides = const []}) => testApp(
  overrides: [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ...overrides,
  ],
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

  testWidgets('emptying a field to retype it keeps the plan values', (
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
    container
        .read(divePlanNotifierProvider.notifier)
        .enableMission(
          MissionEdits.starter(
            legId: 'L1',
            memberId: 'm1',
            memberName: 'Sam',
            sacBottom: 15,
          ).copyWith(
            batteryReserveFraction: 0.25,
            defaultCurrent: const CurrentVector(
              speedMps: 20 / 60,
              setsTowardDeg: 90,
            ),
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.text('DPV team'));
    await tester.pumpAndSettle();
    DpvMission mission() => container.read(divePlanNotifierProvider).mission!;
    Finder box(String label) => find.descendant(
      of: find.widgetWithText(PlanNumberField, label),
      matching: find.byType(TextField),
    );

    // Backspacing the current's speed to retype it keeps its direction.
    await tester.enterText(box('Default current'), '');
    await tester.pump();
    expect(mission().defaultCurrent, isNotNull);
    await tester.enterText(box('Default current'), '30');
    await tester.pump();
    expect(mission().defaultCurrent!.speedMps, closeTo(0.5, 1e-9));
    expect(mission().defaultCurrent!.setsTowardDeg, 90);

    // An emptied reserve is not reset to the default under the diver.
    await tester.enterText(box('Battery reserve'), '');
    await tester.pump();
    expect(mission().batteryReserveFraction, 0.25);

    // Typing 0 is how the diver says there is no default current.
    await tester.enterText(box('Default current'), '0');
    await tester.pump();
    expect(mission().defaultCurrent, isNull);
  });

  Future<ProviderContainer> openTeam(
    WidgetTester tester,
    DpvMission mission, {
    List<dynamic> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(overrides: overrides));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSetupAccordion)),
    );
    container.read(divePlanNotifierProvider.notifier).enableMission(mission);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DPV team'));
    await tester.pumpAndSettle();
    return container;
  }

  Finder box(String label) => find.descendant(
    of: find.widgetWithText(PlanNumberField, label),
    matching: find.byType(TextField),
  );

  final starter = MissionEdits.starter(
    legId: 'L1',
    memberId: 'm1',
    memberName: 'Sam',
    sacBottom: 15,
  );

  testWidgets('open water settings and the current direction are saved', (
    tester,
  ) async {
    final container = await openTeam(
      tester,
      starter.copyWith(
        environment: MissionEnvironment.openWater,
        defaultCurrent: const CurrentVector(
          speedMps: 20 / 60,
          setsTowardDeg: 90,
        ),
      ),
    );
    DpvMission mission() => container.read(divePlanNotifierProvider).mission!;

    await tester.enterText(box('Sets toward'), '270');
    await tester.enterText(box('Walking speed'), '60');
    await tester.enterText(box('Longest surface swim'), '200');
    await tester.pump();
    expect(mission().defaultCurrent!.setsTowardDeg, 270);
    expect(mission().walkSpeedMps, closeTo(1.0, 1e-9));
    expect(mission().surfaceSwimLimitM, 200);

    // An empty limit means none.
    await tester.enterText(box('Longest surface swim'), '');
    await tester.pump();
    expect(mission().surfaceSwimLimitM, isNull);

    await tester.tap(find.text('Overhead'));
    await tester.pumpAndSettle();
    expect(mission().environment, MissionEnvironment.overhead);
    expect(find.text('Walking speed'), findsNothing);
  });

  testWidgets('a diver card edits and removes its diver', (tester) async {
    final container = await openTeam(
      tester,
      MissionEdits.addMember(starter, 'm2', name: 'Alex', sacBottom: 18),
    );
    DpvMission mission() => container.read(divePlanNotifierProvider).mission!;

    await tester.tap(find.text('Sam'));
    await tester.pumpAndSettle();
    expect(find.text('Edit diver'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextField, 'Sam'),
      ),
      'Samantha',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(mission().team.first.displayName, 'Samantha');

    await tester.tap(find.byTooltip('Remove diver').first);
    await tester.pumpAndSettle();
    expect(mission().team.single.displayName, 'Alex');
    // The last diver cannot be removed.
    expect(find.byTooltip('Remove diver'), findsNothing);
  });

  testWidgets('a scooter from equipment shows its battery capacity', (
    tester,
  ) async {
    await openTeam(
      tester,
      MissionEdits.updateMember(
        starter,
        starter.team.single.copyWith(
          scooter: const ScooterSpec(
            equipmentId: 'eq-1',
            name: 'Blacktip',
            ratedSpeedMps: 0.9,
            burnTimeSeconds: 5400,
          ),
        ),
      ),
      overrides: [
        equipmentItemProvider('eq-1').overrideWith(
          (ref) async => EquipmentItem(
            id: 'eq-1',
            name: 'Blacktip',
            type: EquipmentType.dpv,
            attributes: [
              EquipmentAttribute.curated(
                equipmentId: 'eq-1',
                key: 'battery_capacity_wh',
                valueNum: 1000,
              ),
            ],
          ),
        ),
      ],
    );
    expect(find.textContaining('1000 Wh battery'), findsOneWidget);

    // On a narrow phone the wrapped scooter line must not push the battery
    // line out of the card.
    tester.view.physicalSize = const Size(320, 2000);
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(
      find.textContaining('1000 Wh battery'),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
  });

  testWidgets('a value committed as a dialog opens survives its save', (
    tester,
  ) async {
    final container = await openTeam(tester, starter);
    // Out of range: not applied while typing, clamped to 100 on blur.
    await tester.enterText(box('Battery reserve'), '150');
    await tester.pump();
    await tester.tap(find.text('Sam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      container.read(divePlanNotifierProvider).mission!.batteryReserveFraction,
      1.0,
    );
  });

  testWidgets('a new diver takes the lowest free default name', (tester) async {
    final container = await openTeam(
      tester,
      MissionEdits.addMember(
        MissionEdits.starter(
          legId: 'L1',
          memberId: 'm1',
          memberName: 'Diver 1',
          sacBottom: 15,
        ),
        'm2',
        name: 'Diver 2',
        sacBottom: 15,
      ),
    );
    await tester.tap(find.byTooltip('Remove diver').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add diver'));
    await tester.pumpAndSettle();
    final names = [
      for (final m in container.read(divePlanNotifierProvider).mission!.team)
        m.displayName,
    ];
    expect(names, ['Diver 2', 'Diver 1']);
  });

  testWidgets('a diver card shows the buddy or diver photo', (tester) async {
    final buddyPhoto = Uint8List.fromList([1]);
    final diverPhoto = Uint8List.fromList([2]);
    final mission = MissionEdits.addMember(
      starter,
      'm2',
      name: 'Me',
      sacBottom: 15,
    );
    await openTeam(
      tester,
      MissionEdits.updateMember(
        MissionEdits.updateMember(
          mission,
          mission.team.first.copyWith(buddyId: 'b1'),
        ),
        mission.team.last.copyWith(diverId: 'd1'),
      ),
      overrides: [
        buddyByIdProvider('b1').overrideWith(
          (ref) async => Buddy(
            id: 'b1',
            name: 'Sam',
            photo: buddyPhoto,
            createdAt: DateTime(2026, 9, 28),
            updatedAt: DateTime(2026, 9, 28),
          ),
        ),
        diverByIdProvider('d1').overrideWith(
          (ref) async => Diver(
            id: 'd1',
            name: 'Me',
            photo: diverPhoto,
            createdAt: DateTime(2026, 9, 28),
            updatedAt: DateTime(2026, 9, 28),
          ),
        ),
      ],
    );
    ProfileAvatar avatarOf(String name) => tester.widget<ProfileAvatar>(
      find.descendant(
        of: find.widgetWithText(Card, name),
        matching: find.byType(ProfileAvatar),
      ),
    );
    expect(avatarOf('Sam').photo, same(buddyPhoto));
    expect(avatarOf('Me').photo, same(diverPhoto));
  });
}
