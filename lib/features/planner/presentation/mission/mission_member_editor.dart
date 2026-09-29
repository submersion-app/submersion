import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/scooter_spec_resolver.dart';
import 'package:submersion/features/planner/presentation/mission/buddy_picker_sheet.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Edits one diver of a DPV mission: who they are, their SAC and swim
/// speed, and their scooter, picked from equipment or entered by hand.
Future<MissionMember?> showMissionMemberEditor(
  BuildContext context, {
  required MissionMember member,
  required MissionUnits units,
}) {
  return showDialog<MissionMember>(
    context: context,
    builder: (context) => _MissionMemberEditor(member: member, units: units),
  );
}

class _MissionMemberEditor extends StatefulWidget {
  const _MissionMemberEditor({required this.member, required this.units});

  final MissionMember member;
  final MissionUnits units;

  @override
  State<_MissionMemberEditor> createState() => _MissionMemberEditorState();
}

class _MissionMemberEditorState extends State<_MissionMemberEditor> {
  late MissionMember _draft;
  late final TextEditingController _name;
  late final TextEditingController _scooterName;

  @override
  void initState() {
    super.initState();
    _draft = widget.member;
    _name = TextEditingController(text: widget.member.displayName);
    _scooterName = TextEditingController(text: widget.member.scooter.name);
  }

  @override
  void dispose() {
    _name.dispose();
    _scooterName.dispose();
    super.dispose();
  }

  Future<void> _pickWho() async {
    final who = await showBuddyPickerSheet(context);
    if (who == null) return;
    setState(() {
      _name.text = who.name;
      _draft = _draft.copyWith(
        displayName: who.name,
        buddyId: who.buddyId,
        clearBuddyId: who.buddyId == null,
        diverId: who.diverId,
        clearDiverId: who.diverId == null,
      );
    });
  }

  Future<void> _pickScooter() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => EquipmentPickerSheet(
          scrollController: scrollController,
          selectedEquipmentIds: {?_draft.scooter.equipmentId},
          typeFilter: EquipmentType.dpv,
          hideSpare: false,
          onEquipmentSelected: (item) {
            Navigator.of(context).pop();
            // An item logged without a speed or burn time still brings its
            // name, link and whatever numbers it has; validation names the
            // missing ones, and the next load picks them up once logged.
            final spec =
                const ScooterSpecResolver().fromEquipment(item) ??
                ScooterSpec(
                  equipmentId: item.id,
                  name: item.name,
                  ratedSpeedMps: item.dpvSpeedMps ?? 0,
                  burnTimeSeconds: ((item.dpvBurnTimeHours ?? 0) * 3600)
                      .round(),
                  towSpeedFactor:
                      item.dpvTowSpeedFactor ?? kDefaultTowSpeedFactor,
                  towBurnFactor: item.dpvTowBurnFactor ?? kDefaultTowBurnFactor,
                );
            setState(() {
              _scooterName.text = spec.name;
              _draft = _draft.copyWith(scooter: spec);
            });
          },
        ),
      ),
    );
  }

  void _setScooter(ScooterSpec scooter) =>
      setState(() => _draft = _draft.copyWith(scooter: scooter));

  /// A number typed over a picked scooter makes it manual: the next load
  /// must not overwrite the diver's figure from the equipment item.
  void _setScooterNumbers(ScooterSpec scooter) =>
      _setScooter(scooter.copyWith(clearEquipmentId: true));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final u = widget.units;
    final scooter = _draft.scooter;
    return AlertDialog(
      title: Text(l10n.plannerMission_team_editDiver),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: l10n.plannerMission_member_name,
              ),
              onChanged: (v) => _draft = _draft.copyWith(displayName: v),
            ),
            TextButton.icon(
              icon: const Icon(Icons.people_outline),
              label: Text(l10n.plannerMission_member_pickBuddy),
              onPressed: _pickWho,
            ),
            PlanNumberField(
              label: l10n.plannerMission_member_sac,
              value: u.sacDisplay(_draft.sacBottom),
              hintValue: 0,
              suffixText: u.sacSymbol,
              decimals: u.sacDecimals,
              min: 0,
              allowEmpty: false,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(
                  sacBottom: u.sacLitersPerMin(v ?? 0),
                ),
              ),
            ),
            PlanNumberField(
              label: l10n.plannerMission_member_swimSpeed,
              value: u.speedDisplay(_draft.swimSpeedMps),
              hintValue: 0,
              suffixText: u.speedSymbol,
              decimals: 0,
              min: 0,
              allowEmpty: false,
              onChanged: (v) => setState(
                () =>
                    _draft = _draft.copyWith(swimSpeedMps: u.speedMps(v ?? 0)),
              ),
            ),
            const Divider(),
            Text(l10n.plannerMission_member_scooter),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _pickScooter,
                  child: Text(l10n.plannerMission_member_chooseScooter),
                ),
                OutlinedButton(
                  onPressed: () =>
                      _setScooter(scooter.copyWith(clearEquipmentId: true)),
                  child: Text(l10n.plannerMission_member_manualScooter),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _scooterName,
              decoration: InputDecoration(
                labelText: l10n.plannerMission_scooter_name,
              ),
              onChanged: (v) => _setScooter(scooter.copyWith(name: v)),
            ),
            PlanNumberField(
              label: l10n.plannerMission_scooter_speed,
              value: u.speedDisplay(scooter.ratedSpeedMps),
              hintValue: 0,
              suffixText: u.speedSymbol,
              decimals: 0,
              min: 0,
              allowEmpty: false,
              onChanged: (v) => _setScooterNumbers(
                scooter.copyWith(ratedSpeedMps: u.speedMps(v ?? 0)),
              ),
            ),
            PlanNumberField(
              label: l10n.plannerMission_scooter_burnTime,
              value: scooter.burnTimeSeconds / 60,
              hintValue: 0,
              suffixText: 'min',
              isInteger: true,
              decimals: 0,
              min: 0,
              allowEmpty: false,
              onChanged: (v) => _setScooterNumbers(
                scooter.copyWith(burnTimeSeconds: ((v ?? 0) * 60).round()),
              ),
            ),
            PlanNumberField(
              label: l10n.plannerMission_scooter_towSpeedFactor,
              value: scooter.towSpeedFactor,
              hintValue: kDefaultTowSpeedFactor,
              suffixText: '',
              decimals: 2,
              min: 0,
              max: 1,
              allowEmpty: false,
              onChanged: (v) => _setScooterNumbers(
                scooter.copyWith(towSpeedFactor: v ?? kDefaultTowSpeedFactor),
              ),
            ),
            PlanNumberField(
              label: l10n.plannerMission_scooter_towBurnFactor,
              value: scooter.towBurnFactor,
              hintValue: kDefaultTowBurnFactor,
              suffixText: '',
              decimals: 2,
              min: 1,
              allowEmpty: false,
              onChanged: (v) => _setScooterNumbers(
                scooter.copyWith(towBurnFactor: v ?? kDefaultTowBurnFactor),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(_draft.copyWith(displayName: _name.text.trim())),
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
