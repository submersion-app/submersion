import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_pairing_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_pairing_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

const _log = LoggerService('twinSetLinkFlow');

/// The cylinders [cylinder] can be paired with (issue #4242): the diver's
/// other cylinders, own or shared, except those retired, sold or lost. A
/// spare is offered, since a spare is what gets swapped in after a failed
/// test.
List<EquipmentItem> twinPartnerCandidates(
  List<EquipmentItem> gear,
  String cylinderId,
) => [
  for (final item in gear)
    if (item.type == EquipmentType.tank &&
        item.id != cylinderId &&
        !const {
          EquipmentStatus.retired,
          EquipmentStatus.sold,
          EquipmentStatus.lost,
          EquipmentStatus.wanted,
        }.contains(item.effectiveStatus))
      item,
];

/// Picks a twin set partner for [cylinderId]. Null when dismissed.
Future<EquipmentItem?> showTwinPartnerPicker(
  BuildContext context, {
  required String cylinderId,
}) => showModalBottomSheet<EquipmentItem>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _TwinPartnerPicker(cylinderId: cylinderId),
);

class _TwinPartnerPicker extends ConsumerWidget {
  const _TwinPartnerPicker({required this.cylinderId});

  final String cylinderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final gear = ref.watch(activeEquipmentProvider).value;
    final candidates = gear == null
        ? null
        : twinPartnerCandidates(gear, cylinderId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            l10n.twinSet_pickerTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (candidates == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.twinSet_pickerEmpty),
          )
        else
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final item in candidates)
                  ListTile(
                    title: Text(item.name),
                    subtitle: _specLine(item, units),
                    onTap: () => Navigator.of(context).pop(item),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget? _specLine(EquipmentItem item, UnitFormatter units) {
    final parts = [
      if (item.volumeL case final v?)
        units.formatTankVolume(v, item.workingPressureBar),
      if (item.workingPressureBar case final p?) units.formatPressure(p),
    ];
    return parts.isEmpty ? null : Text(parts.join(', '));
  }
}

/// Links [cylinder] to a partner the diver picks, from a day they choose
/// (today unless changed): warns when the working pressures differ, offers
/// to replace a partner either cylinder already has, and names any other
/// pairing the new one would overlap. Replace partner runs the same flow.
Future<void> linkTwinSetPartner(
  BuildContext context,
  WidgetRef ref,
  EquipmentItem cylinder,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final partner = await showTwinPartnerPicker(context, cylinderId: cylinder.id);
  if (partner == null || !context.mounted) return;
  final now = DateTime.now();
  final pairedOn = await showAppDatePicker(
    context: context,
    initialDate: now,
    firstDate: DateTime(1990),
    lastDate: now,
    helpText: l10n.twinSet_pairedOnHelp,
  );
  if (pairedOn == null || !context.mounted) return;
  if (!await _acceptPressures(context, ref, cylinder, partner)) return;
  if (!context.mounted) return;
  final repository = ref.read(cylinderPairingRepositoryProvider);
  try {
    try {
      await repository.createPairing(
        cylinderAId: cylinder.id,
        cylinderBId: partner.id,
        pairedOn: pairedOn,
      );
    } on PairingClash catch (clash) {
      if (!context.mounted) return;
      final start = calendarDay(pairedOn);
      final replaceable = clash.clashes.every(
        (c) => c.isOpen && c.pairedOn.isBefore(start),
      );
      if (!replaceable) {
        await _showClash(context, ref, clash.clashes);
        return;
      }
      final replace = await _confirmReplace(
        context,
        ref,
        cylinder: cylinder,
        partner: partner,
        clashes: clash.clashes,
      );
      if (!replace) return;
      await repository.createPairing(
        cylinderAId: cylinder.id,
        cylinderBId: partner.id,
        pairedOn: pairedOn,
        replace: true,
      );
    }
  } on PairingClash catch (clash) {
    if (context.mounted) await _showClash(context, ref, clash.clashes);
  } catch (e, stackTrace) {
    _log.error('Failed to link a twin set', error: e, stackTrace: stackTrace);
    messenger.showSnackBar(SnackBar(content: Text(l10n.twinSet_saveFailed)));
  }
}

/// Ends [pairing] on a day the diver picks (today unless changed).
Future<void> unlinkTwinSet(
  BuildContext context,
  WidgetRef ref,
  CylinderPairing pairing,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final units = UnitFormatter(ref.read(settingsProvider));
  final today = calendarDay(DateTime.now());
  final firstEnd = pairing.pairedOn.add(const Duration(days: 1));
  final lastDate = firstEnd.isAfter(today) ? firstEnd : today;
  final picked = await showAppDatePicker(
    context: context,
    initialDate: _local(lastDate),
    firstDate: _local(firstEnd),
    lastDate: _local(lastDate),
    helpText: l10n.twinSet_unpairedOnHelp,
  );
  if (picked == null || !context.mounted) return;
  try {
    await ref
        .read(cylinderPairingRepositoryProvider)
        .endPairing(pairing.id, picked);
  } on ArgumentError {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.twinSet_endBeforeStart(units.formatDate(pairing.pairedOn)),
        ),
      ),
    );
  } on PairingClash catch (clash) {
    if (context.mounted) await _showClash(context, ref, clash.clashes);
  } catch (e, stackTrace) {
    _log.error('Failed to unlink a twin set', error: e, stackTrace: stackTrace);
    messenger.showSnackBar(SnackBar(content: Text(l10n.twinSet_saveFailed)));
  }
}

/// A calendar day as a local date, for the date picker.
DateTime _local(DateTime day) => DateTime(day.year, day.month, day.day);

/// Asks before pairing two cylinders rated for different pressures. True
/// when they match, a rating is unknown, or the diver goes ahead.
Future<bool> _acceptPressures(
  BuildContext context,
  WidgetRef ref,
  EquipmentItem a,
  EquipmentItem b,
) async {
  final aBar = a.workingPressureBar;
  final bBar = b.workingPressureBar;
  if (aBar == null || bBar == null || (aBar - bBar).abs() < 1) return true;
  final l10n = context.l10n;
  final units = UnitFormatter(ref.read(settingsProvider));
  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.twinSet_pressureMismatchTitle),
      content: Text(
        l10n.twinSet_pressureMismatchBody(
          a.name,
          units.formatPressure(aBar),
          b.name,
          units.formatPressure(bBar),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.forms_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.twinSet_continue),
        ),
      ],
    ),
  );
  return go ?? false;
}

Future<String> _nameOf(WidgetRef ref, String id) async {
  try {
    return (await ref.read(equipmentItemProvider(id).future))?.name ?? id;
  } catch (_) {
    return id;
  }
}

Future<bool> _confirmReplace(
  BuildContext context,
  WidgetRef ref, {
  required EquipmentItem cylinder,
  required EquipmentItem partner,
  required List<CylinderPairing> clashes,
}) async {
  final l10n = context.l10n;
  final lines = <String>[];
  final leftAlone = <String>[];
  for (final c in clashes) {
    final mine = c.involves(cylinder.id) ? cylinder : partner;
    final other = c.partnerOf(mine.id);
    final otherName = await _nameOf(ref, other);
    lines.add(l10n.twinSet_replaceClash(mine.name, otherName));
    if (other != cylinder.id && other != partner.id) leftAlone.add(otherName);
  }
  lines.add(l10n.twinSet_replaceQuestion(cylinder.name, partner.name));
  lines.addAll(leftAlone.map(l10n.twinSet_leftAlone));
  if (!context.mounted) return false;
  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.twinSet_replaceTitle),
      content: Text(lines.join(' ')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.forms_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.twinSet_replaceConfirm),
        ),
      ],
    ),
  );
  return go ?? false;
}

Future<void> _showClash(
  BuildContext context,
  WidgetRef ref,
  List<CylinderPairing> clashes,
) async {
  final AppLocalizations l10n = context.l10n;
  final pairs = <String>[
    for (final c in clashes)
      l10n.twinSet_pairNames(
        await _nameOf(ref, c.cylinderAId),
        await _nameOf(ref, c.cylinderBId),
      ),
  ];
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.twinSet_clashTitle),
      content: Text(l10n.twinSet_clashBody(pairs.join('; '))),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
        ),
      ],
    ),
  );
}
