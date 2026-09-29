import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';
import 'package:submersion/features/planner/presentation/mission/buddy_picker_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/presentation/mission/mission_member_editor.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The "DPV team" accordion section: one card per diver, then the mission's
/// own settings (environment, battery reserve, default current and, in open
/// water, walking speed and the longest surface swim).
class MissionTeamSection extends ConsumerWidget {
  const MissionTeamSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mission = ref.watch(
      divePlanNotifierProvider.select((s) => s.mission),
    );
    if (mission == null) return const SizedBox.shrink();
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final units = MissionUnits(UnitFormatter(ref.watch(settingsProvider)));
    final l10n = context.l10n;
    final defaultCurrent = mission.defaultCurrent;
    final openWater = mission.environment == MissionEnvironment.openWater;

    Future<void> edit(MissionMember member) async {
      final edited = await showMissionMemberEditor(
        context,
        member: member,
        units: units,
      );
      if (edited != null) {
        notifier.editMission((m) => MissionEdits.updateMember(m, edited));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final member in mission.team)
          _MemberCard(
            member: member,
            units: units,
            onEdit: () => edit(member),
            onRemove: mission.team.length == 1
                ? null
                : () => notifier.editMission(
                    (m) => MissionEdits.removeMember(m, member.id),
                  ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Tooltip(
            message: l10n.plannerMission_team_addDiver,
            child: TextButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.plannerMission_team_addDiver),
              onPressed: () => notifier.editMission(
                (m) => MissionEdits.addMember(
                  m,
                  const Uuid().v4(),
                  name: MissionEdits.nextDefaultName(
                    m,
                    l10n.plannerMission_team_defaultName,
                  ),
                  // A new diver starts on the first diver's SAC; the plan's
                  // own SAC seeded that one.
                  sacBottom: m.team.isEmpty
                      ? ref.read(divePlanNotifierProvider).sacRate
                      : m.team.first.sacBottom,
                ),
              ),
            ),
          ),
        ),
        const Divider(),
        Text(l10n.plannerMission_settings_environment),
        SegmentedButton<MissionEnvironment>(
          segments: [
            ButtonSegment(
              value: MissionEnvironment.overhead,
              label: Text(l10n.plannerMission_environment_overhead),
            ),
            ButtonSegment(
              value: MissionEnvironment.openWater,
              label: Text(l10n.plannerMission_environment_openWater),
            ),
          ],
          selected: {mission.environment},
          onSelectionChanged: (s) =>
              notifier.editMission((m) => m.copyWith(environment: s.single)),
        ),
        PlanNumberField(
          label: l10n.plannerMission_settings_batteryReserve,
          value: mission.batteryReserveFraction * 100,
          hintValue: kDefaultBatteryReserveFraction * 100,
          suffixText: '%',
          decimals: 0,
          min: 0,
          max: 100,
          allowEmpty: false,
          onChanged: (v) {
            if (v == null) return;
            notifier.editMission(
              (m) => m.copyWith(batteryReserveFraction: v / 100),
            );
          },
        ),
        PlanNumberField(
          label: l10n.plannerMission_settings_defaultCurrent,
          value: defaultCurrent == null
              ? null
              : units.speedDisplay(defaultCurrent.speedMps),
          hintValue: 0,
          suffixText: units.speedSymbol,
          decimals: 0,
          min: 0,
          // An emptied box is the diver retyping; 0 says there is none.
          allowEmpty: false,
          onChanged: (v) {
            if (v == null) return;
            notifier.editMission(
              (m) => v == 0
                  ? m.copyWith(clearDefaultCurrent: true)
                  : m.copyWith(
                      defaultCurrent: CurrentVector(
                        speedMps: units.speedMps(v),
                        setsTowardDeg: m.defaultCurrent?.setsTowardDeg ?? 0,
                      ),
                    ),
            );
          },
        ),
        if (defaultCurrent != null)
          PlanNumberField(
            label: l10n.plannerMission_current_setsToward,
            value: defaultCurrent.setsTowardDeg,
            hintValue: 0,
            suffixText: '°',
            decimals: 0,
            min: 0,
            max: 359,
            allowEmpty: false,
            onChanged: (v) {
              if (v == null) return;
              notifier.editMission(
                (m) => m.copyWith(
                  defaultCurrent: CurrentVector(
                    speedMps:
                        m.defaultCurrent?.speedMps ?? defaultCurrent.speedMps,
                    setsTowardDeg: v,
                  ),
                ),
              );
            },
          ),
        if (openWater) ...[
          PlanNumberField(
            label: l10n.plannerMission_settings_walkSpeed,
            value: units.speedDisplay(mission.walkSpeedMps),
            hintValue: units.speedDisplay(kDefaultWalkSpeedMps),
            suffixText: units.speedSymbol,
            decimals: 0,
            min: 0,
            allowEmpty: false,
            onChanged: (v) {
              if (v == null) return;
              notifier.editMission(
                (m) => m.copyWith(walkSpeedMps: units.speedMps(v)),
              );
            },
          ),
          PlanNumberField(
            label: l10n.plannerMission_settings_surfaceSwimLimit,
            value: mission.surfaceSwimLimitM == null
                ? null
                : units.distanceDisplay(mission.surfaceSwimLimitM!),
            hintValue: 0,
            suffixText: units.distanceSymbol,
            decimals: 0,
            min: 0,
            onChanged: (v) => notifier.editMission(
              (m) => v == null
                  ? m.copyWith(clearSurfaceSwimLimit: true)
                  : m.copyWith(surfaceSwimLimitM: units.distanceMeters(v)),
            ),
          ),
        ],
      ],
    );
  }
}

class _MemberCard extends ConsumerWidget {
  const _MemberCard({
    required this.member,
    required this.units,
    required this.onEdit,
    required this.onRemove,
  });

  final MissionMember member;
  final MissionUnits units;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scooter = member.scooter;
    final hasScooter = scooter.ratedSpeedMps > 0 && scooter.burnTimeSeconds > 0;
    // Capacity is for information only and is not part of the snapshot, so
    // it comes from the live item a picked scooter still points at.
    final equipmentId = scooter.equipmentId;
    final capacityWh = equipmentId == null
        ? null
        : ref
              .watch(equipmentItemProvider(equipmentId))
              .value
              ?.dpvBatteryCapacityWh;
    return Card(
      child: ListTile(
        leading: _MemberAvatar(member: member),
        title: Text(
          member.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            l10n.plannerMission_team_memberSummary(
              units.sac(member.sacBottom),
              units.speed(member.swimSpeedMps),
            ),
            if (hasScooter)
              // Placeholders are alphabetical: minutes, name, speed.
              l10n.plannerMission_team_scooterSummary(
                (scooter.burnTimeSeconds / 60).round().toString(),
                scooter.name,
                units.speed(scooter.ratedSpeedMps),
              )
            else
              l10n.plannerMission_team_noScooter,
            if (capacityWh != null)
              l10n.plannerMission_team_capacity(capacityWh.round().toString()),
          ].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onEdit,
        trailing: onRemove == null
            ? null
            : IconButton(
                icon: const Icon(Icons.delete, size: 18),
                tooltip: l10n.plannerMission_team_removeDiver,
                onPressed: onRemove,
              ),
      ),
    );
  }
}

/// The photo of the buddy or diver profile a team member was picked from,
/// else the member's initials.
class _MemberAvatar extends ConsumerWidget {
  const _MemberAvatar({required this.member});

  final MissionMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buddyId = member.buddyId;
    final diverId = member.diverId;
    if (buddyId != null) {
      final buddy = ref.watch(buddyByIdProvider(buddyId)).value;
      if (buddy != null) return MissionBuddyAvatar(buddy: buddy);
    } else if (diverId != null) {
      final diver = ref.watch(diverByIdProvider(diverId)).value;
      if (diver != null) {
        return ProfileAvatar(photo: diver.photo, initials: diver.initials);
      }
    }
    return ProfileAvatar(photo: null, initials: _initials(member.displayName));
  }

  /// First and last initials, as buddy and diver profiles show them.
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    final only = parts.first;
    return only.isEmpty ? '?' : only[0].toUpperCase();
  }
}
