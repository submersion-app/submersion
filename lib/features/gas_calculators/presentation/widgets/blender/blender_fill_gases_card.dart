import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/locale_number_symbols.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_gas_role.dart';
import 'package:submersion/features/gas_calculators/domain/blending/flush_fee.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_decimal_digits_formatter.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_formatting.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_responsive_field_row.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_section_title.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_volume_conversion.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The three fill-gas roles the blender draws from -- oxygen, helium and
/// topup -- one row each, in the diver's configured fill order.
///
/// Oxygen and helium are fixed at 100% purity; only the topup role's oxygen
/// fraction is editable (issue #42). Reordering with the up/down arrows
/// changes the fill sequence, not the roles themselves, so a price and a
/// purge volume both stay attached to their role's row wherever that row
/// sits in the list.
class BlenderFillGasesCard extends ConsumerWidget {
  const BlenderFillGasesCard({
    super.key,
    required this.topupO2Controller,
    required this.priceControllers,
    required this.flushVolumeControllers,
  });

  /// The topup role's oxygen-percentage field.
  final TextEditingController topupO2Controller;

  /// Price per 100 litres for each role, indexed by [BlenderGasRole.index]
  /// -- not by fill order -- so a price stays put when the rows above it
  /// are reordered (Eric's PR #1359 review point 3: the price sits next to
  /// the gas it prices rather than in a separate card).
  final List<TextEditingController> priceControllers;

  /// Hose-purge volume for each role, indexed by [BlenderGasRole.index] --
  /// not by fill order -- same reordering guarantee as [priceControllers].
  /// Moved here from the Cost card (issue #42 follow-up) so the purge volume
  /// is entered once, next to the price it is billed at, rather than on a
  /// card the diver reopens every fill.
  final List<TextEditingController> flushVolumeControllers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final order = ref.watch(blenderFillOrderProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlenderSectionTitle(context.l10n.gasCalculators_blender_fillGases),
            for (var position = 0; position < order.length; position++) ...[
              if (position > 0) const SizedBox(height: 16),
              _roleRow(
                context,
                ref,
                role: order[position],
                position: position,
                order: order,
                units: units,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _roleRow(
    BuildContext context,
    WidgetRef ref, {
    required BlenderGasRole role,
    required int position,
    required List<BlenderGasRole> order,
    required UnitFormatter units,
  }) {
    final label = blenderGasRoleLabel(context, role);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
            IconButton(
              key: Key('blender-gas-move-up-${role.name}'),
              icon: const Icon(Icons.arrow_upward),
              tooltip: context.l10n.gasCalculators_blender_moveGasUp(label),
              visualDensity: VisualDensity.compact,
              onPressed: position == 0
                  ? null
                  : () => _move(ref, order, position, position - 1),
            ),
            IconButton(
              key: Key('blender-gas-move-down-${role.name}'),
              icon: const Icon(Icons.arrow_downward),
              tooltip: context.l10n.gasCalculators_blender_moveGasDown(label),
              visualDensity: VisualDensity.compact,
              onPressed: position == order.length - 1
                  ? null
                  : () => _move(ref, order, position, position + 1),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Oxygen and helium are fixed at 100% purity, so the fraction isn't
        // shown at all for those roles -- not even as read-only text (issue
        // #44 follow-up): a fixed value nobody can change is not information
        // a diver needs on this card. Only the topup role's mix is
        // configurable, so its row carries a third field. All three fields
        // sit side by side when there is room, and stack on a narrow screen
        // (issue #1876), the same for every role rather than singling
        // Topup's mix field out with its own fixed-width pairing.
        BlenderResponsiveFieldRow(
          fields: [
            if (role == BlenderGasRole.topup) _topupO2Field(context, ref),
            _priceField(context, ref, role, units),
            _flushVolumeField(context, ref, role, units),
          ],
        ),
      ],
    );
  }

  Widget _topupO2Field(BuildContext context, WidgetRef ref) {
    return TextField(
      key: const Key('blender-topup-o2'),
      controller: topupO2Controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        const BlenderDecimalDigitsFormatter(),
      ],
      decoration: InputDecoration(
        labelText: '${context.l10n.gasCalculators_blender_o2} (%)',
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) => ref.read(blenderTopupO2PercentProvider.notifier).state =
          (smartParseUserDecimal(v) ?? 0.0).clamp(0.0, 100.0),
      onEditingComplete: () => saveBlenderPreferences(ref),
      onSubmitted: (_) => saveBlenderPreferences(ref),
    );
  }

  Widget _priceField(
    BuildContext context,
    WidgetRef ref,
    BlenderGasRole role,
    UnitFormatter units,
  ) {
    final controller = priceControllers[role.index];
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => TextField(
        key: Key('blender-gas-price-${role.name}'),
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          // 5 digits, not the 3-digit default: a metric price per 100 L
          // converts to roughly 28x itself per 100 cuft (issue #1876
          // Copilot review), so a perfectly ordinary 50/100L becomes
          // ~1416/100cuft -- 3 digits would make that unreadable.
          const BlenderDecimalDigitsFormatter(maxIntDigits: 5),
        ],
        decoration: InputDecoration(
          labelText: context.l10n.gasCalculators_blender_unitPrice(
            units.volumeSymbol,
          ),
          errorText: _invalidNumberText(context, controller.text),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => _onPriceChanged(ref),
        onEditingComplete: () => saveBlenderPreferences(ref),
        onSubmitted: (_) => saveBlenderPreferences(ref),
      ),
    );
  }

  /// The error to show under a decimal field when [text] is non-blank but
  /// still cannot be read after [smartParseUserDecimal] has already
  /// corrected an unambiguous wrong-separator keystroke -- the one shape
  /// left is genuinely malformed (e.g. two separators), not a diver's `.`
  /// under a German locale, which is corrected automatically (#1876).
  String? _invalidNumberText(BuildContext context, String text) {
    if (text.trim().isEmpty || smartParseUserDecimal(text) != null) {
      return null;
    }
    return context.l10n.gasCalculators_blender_invalidNumber(
      localeNumberFormat().symbols.DECIMAL_SEP,
    );
  }

  /// Rebuilds the whole role-indexed price list from every row's controller.
  ///
  /// Blank text clears a role's price to null (no price set yet). Unreadable,
  /// non-blank text keeps whatever was stored before rather than silently
  /// discarding a price the diver already entered -- the field's `errorText`
  /// is what tells them the keystroke was rejected.
  void _onPriceChanged(WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    final previous = ref.read(blenderGasPricesProvider);
    ref.read(blenderGasPricesProvider.notifier).state = [
      for (var i = 0; i < priceControllers.length; i++)
        _priceOrKeep(priceControllers[i].text, previous, i, settings),
    ];
  }

  double? _priceOrKeep(
    String text,
    List<double?> previous,
    int index,
    AppSettings settings,
  ) {
    if (text.trim().isEmpty) return null;
    final parsed = smartParseUserDecimal(text);
    if (parsed == null) {
      return index < previous.length ? previous[index] : null;
    }
    return displayToPricePer100Liters(parsed, settings);
  }

  Widget _flushVolumeField(
    BuildContext context,
    WidgetRef ref,
    BlenderGasRole role,
    UnitFormatter units,
  ) {
    final label = blenderGasRoleLabel(context, role);
    final controller = flushVolumeControllers[role.index];
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => TextField(
        key: Key('blender-flush-fee-volume-${role.name}'),
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          const BlenderDecimalDigitsFormatter(),
        ],
        decoration: InputDecoration(
          labelText:
              '$label '
              '${context.l10n.gasCalculators_blender_flushFeeVolume} '
              '(${units.volumeSymbol})',
          errorText: _invalidNumberText(context, controller.text),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => _onFlushVolumeChanged(ref),
        onEditingComplete: () => saveBlenderPreferences(ref),
        onSubmitted: (_) => saveBlenderPreferences(ref),
      ),
    );
  }

  /// Rebuilds the whole role-indexed flush-volume list from every row's
  /// controller, mirroring [_onPriceChanged]: blank clears to zero (no purge
  /// volume set), unreadable non-blank text keeps whatever was stored before
  /// instead of silently zeroing a volume the diver already entered.
  void _onFlushVolumeChanged(WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    final previous = ref.read(blenderFlushFeeGasesProvider);
    ref.read(blenderFlushFeeGasesProvider.notifier).state = [
      for (var i = 0; i < flushVolumeControllers.length; i++)
        FlushFeeGasSetting(
          volumeLiters: _flushVolumeOrKeep(
            flushVolumeControllers[i].text,
            previous,
            i,
            settings,
          ),
        ),
    ];
  }

  double _flushVolumeOrKeep(
    String text,
    List<FlushFeeGasSetting> previous,
    int index,
    AppSettings settings,
  ) {
    if (text.trim().isEmpty) return 0;
    final parsed = smartParseUserDecimal(text);
    if (parsed == null) {
      return index < previous.length ? previous[index].volumeLiters : 0;
    }
    return displayVolumeToLiters(parsed, settings);
  }

  void _move(WidgetRef ref, List<BlenderGasRole> order, int from, int to) {
    final updated = List.of(order);
    final role = updated.removeAt(from);
    updated.insert(to, role);
    ref.read(blenderFillOrderProvider.notifier).state = updated;
    saveBlenderPreferences(ref);
  }
}
