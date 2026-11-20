import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/gas_percent.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_metrics.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/write_fill_to_tag.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_fills_sitting.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// The newest fill: mix, pressure, station, and the depth limits at the
/// diver's own ppO2 limits (spec section 8, Current fill card).
class PassportCurrentFillCard extends ConsumerWidget {
  const PassportCurrentFillCard({
    super.key,
    required this.equipmentId,
    required this.passportId,
    this.editing,
  });

  final String equipmentId;

  /// The passport id a new fill is logged under: the sitting's, when it
  /// links a tag.
  final String? passportId;

  /// The open card's sitting (issue #4527, phase 3): a fill logged here is held
  /// there until Save, and the tag write is offered after Save. With no sitting
  /// given, no fill can be logged; during a sitting every view shows the
  /// sitting's newest fill.
  final EditSession<EquipmentItem>? editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = RecordEditScope.maybeOf<EquipmentItem>(context);
    final session = editing ?? scope?.session;
    final mayAct = scope == null || editing != null;
    if (session == null) return _build(context, ref, null, mayAct);
    return ListenableBuilder(
      listenable: gearItemFillsList.changes(session),
      builder: (context, _) => _build(context, ref, session, mayAct),
    );
  }

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    EditSession<EquipmentItem>? session,
    bool mayAct,
  ) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final held = session == null ? null : gearItemFillsList.current(session);
    final storedNewest = ref.watch(newestFillProvider(equipmentId)).value;
    final newest = held == null ? storedNewest : held.firstOrNull;
    final editing = this.editing;
    final canAct = mayAct && (editing == null || held != null);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    l10n.passport_fill_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (session != null &&
                    newest != null &&
                    isHeldFill(session, newest)) ...[
                  const SizedBox(width: 6),
                  const RecordChangedDot(),
                ],
                // The fills card's pencil is on the Fill history card below,
                // which shares this card's frame.
              ],
            ),
            const SizedBox(height: 8),
            if (newest == null)
              Text(l10n.passport_fill_none)
            else
              _FillSummary(fill: newest, units: units),
            if (canAct) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: passportId == null
                      ? null
                      : () => _log(context, ref, editing),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.passport_fill_log),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension on PassportCurrentFillCard {
  /// Logs a fill: written at once and offered for the tag, or held in
  /// [editing] until Save, which offers it then.
  Future<void> _log(
    BuildContext context,
    WidgetRef ref,
    EditSession<EquipmentItem>? editing,
  ) async {
    if (editing != null) {
      await showLogFillSheet(
        context,
        passportId: passportId!,
        equipmentId: equipmentId,
        onHold: (fill, {twinPartnerId, toTied = false}) =>
            holdLoggedFill(editing, fill, twinPartnerId: twinPartnerId),
        pairingOn: sittingPairingOn(editing),
      );
      return;
    }
    final saved = await showLogFillSheet(
      context,
      passportId: passportId!,
      equipmentId: equipmentId,
    );
    if (saved == null || !context.mounted) return;
    await offerWriteFillsToTags(context, ref, saved, equipmentId: equipmentId);
  }
}

class _FillSummary extends StatelessWidget {
  const _FillSummary({required this.fill, required this.units});

  final CylinderFill fill;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final limits = PassportGasLimits.compute(
      mix: fill.gasMix,
      ppO2Working: units.settings.ppO2MaxWorking,
      ppO2Deco: units.settings.ppO2MaxDeco,
      o2Narcotic: units.settings.o2Narcotic,
    );
    String ppo2(double v) => formatFixedForDisplay(v, 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(fill.gasMix.name, style: theme.textTheme.headlineSmall),
            const SizedBox(width: 12),
            if (fill.pressureBar != null)
              Text(units.formatPressure(fill.pressureBar)),
            const Spacer(),
            FillSourceBadge(fill: fill),
          ],
        ),
        Text(units.formatDate(fill.filledAt)),
        Text(
          l10n.passport_fill_analysis(
            formatGasPercent(fill.o2Percent),
            formatGasPercent(fill.hePercent),
          ),
        ),
        if (fill.stationName != null)
          Text(l10n.passport_fill_station(fill.stationName!)),
        if (fill.analyzer != null)
          Text(l10n.passport_fill_analyzer(fill.analyzer!)),
        if (fill.temperatureC != null)
          Text(
            l10n.passport_fill_temperature(
              units.formatTemperature(fill.temperatureC),
            ),
          ),
        // Nothing on a tag is signed: its fill is what someone typed.
        if (fill.source == FillSource.nfc)
          Text(
            l10n.passport_fill_analyseBeforeDiving,
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        Text(
          l10n.passport_fill_mod(
            units.formatDepth(limits.modWorkingM),
            ppo2(units.settings.ppO2MaxWorking),
          ),
        ),
        Text(
          l10n.passport_fill_mod(
            units.formatDepth(limits.modDecoM),
            ppo2(units.settings.ppO2MaxDeco),
          ),
        ),
        if (limits.endAtWorkingModM != null)
          Text(
            l10n.passport_fill_end(units.formatDepth(limits.endAtWorkingModM)),
          ),
      ],
    );
  }
}

/// Where a fill came from, when that matters (spec section 11): "From tag"
/// for a fill read from the cylinder's NFC tag. Nothing is signed, so
/// nothing claims to be verified; a fill the diver logged needs no badge.
class FillSourceBadge extends StatelessWidget {
  const FillSourceBadge({super.key, required this.fill});

  final CylinderFill fill;

  @override
  Widget build(BuildContext context) {
    if (fill.source != FillSource.nfc) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Semantics(
      label: context.l10n.passport_fill_fromTag,
      child: Chip(
        label: Text(context.l10n.passport_fill_fromTag),
        avatar: const Icon(Icons.nfc, size: 18),
        labelStyle: theme.textTheme.labelSmall,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
