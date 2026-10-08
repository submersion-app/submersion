import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blend_billing.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_gas_role.dart';
import 'package:submersion/features/gas_calculators/domain/blending/flush_fee.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_cylinder_picker.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_formatting.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_responsive_header_row.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_section_title.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_table_style.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_volume_conversion.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// What the blend costs at the fill station's prices.
///
/// Placed after the safety note, as issue #1100 asks. The cylinder appears
/// only here: partial-pressure mixing is driven by pressure and needs no
/// cylinder, but a bill does.
class BlenderBillingCard extends ConsumerStatefulWidget {
  const BlenderBillingCard({super.key});

  @override
  ConsumerState<BlenderBillingCard> createState() => _BlenderBillingCardState();
}

class _BlenderBillingCardState extends ConsumerState<BlenderBillingCard> {
  late final TextEditingController _cylinder;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    final liters = ref.read(blenderCylinderLitersProvider);
    _cylinder = TextEditingController(
      text: formatRoundedForInput(litersToDisplayVolume(liters, settings), 2),
    );
  }

  @override
  void dispose() {
    _cylinder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final billing = ref.watch(blenderBillingProvider);
    final currency = ref.watch(blenderCurrencyProvider);
    final decimals = pressureDecimalsFor(settings.pressureUnit);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlenderSectionTitle(context.l10n.gasCalculators_blender_billing),
            _cylinderRow(context, settings, units),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _flushFeeSettings(context, settings, units, currency),
            if (billing.lines.isNotEmpty) ...[
              const Divider(height: 28),
              _costTable(
                context,
                billing.lines,
                units,
                settings,
                currency,
                decimals,
              ),
              const Divider(height: 20),
              _totalLine(context, billing, currency),
              const SizedBox(height: 8),
              Text(
                context.l10n.gasCalculators_blender_costBasis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const Key('blender-save-fill'),
                  onPressed: () => _saveFill(context, billing, currency),
                  icon: const Icon(Icons.playlist_add, size: 18),
                  label: Text(context.l10n.gasCalculators_blender_saveFill),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Put the current blend on the running bill.
  ///
  /// The figures are frozen at save time rather than referenced: the next
  /// cylinder is about to replace this blend, and a bill has to survive that.
  void _saveFill(BuildContext context, BillingResult billing, String currency) {
    final target = ref.read(blenderTargetMixProvider);
    final label = formatPreciseMix(context, target);
    final cylinderLiters = ref.read(blenderCylinderLitersProvider);
    final fill = BilledFill(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: label,
      lines: [
        for (final line in billing.lines)
          BilledGasLine(
            gas: formatPreciseGasName(context, line.gas),
            addedBar: line.addedBar,
            cost: line.cost,
            freeGasLiters: line.freeGasLiters,
            cylinderLiters: cylinderLiters,
          ),
      ],
      total: billing.total,
    );
    ref.read(blenderBilledFillsProvider.notifier).state = appendCapped(
      ref.read(blenderBilledFillsProvider),
      fill,
    );
    saveBlenderPreferences(ref);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(context.l10n.gasCalculators_blender_fillAdded(label)),
      ),
    );
  }

  Widget _cylinderRow(
    BuildContext context,
    AppSettings settings,
    UnitFormatter units,
  ) {
    return BlenderResponsiveHeaderRow(
      rowCrossAxisAlignment: CrossAxisAlignment.start,
      leading: NumberField(
        controller: _cylinder,
        decoration: InputDecoration(
          labelText:
              '${context.l10n.gasCalculators_blender_cylinderVolume} '
              '(${units.volumeSymbol})',
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (read) {
          final liters = ref.read(blenderCylinderLitersProvider.notifier);
          liters.state = switch (read) {
            NumberValue(:final value) => displayVolumeToLiters(value, settings),
            NumberBlank() => 0, // no cylinder volume yet, as before
            // Used to read as 0 L too; keep it, the field says why.
            NumberInvalid() => liters.state,
          };
        },
        onEditingComplete: () => saveBlenderPreferences(ref),
        onFieldSubmitted: (_) => saveBlenderPreferences(ref),
      ),
      trailing: TextButton.icon(
        key: const Key('blender-billing-choose-cylinder'),
        icon: const Icon(Icons.propane_tank_outlined, size: 18),
        label: Text(context.l10n.gasCalculators_blender_chooseCylinder),
        onPressed: () => _chooseCylinder(context, settings),
      ),
    );
  }

  /// Picks one of the diver's own tanks for its water volume (issue #2926).
  /// A customer's cylinder, which has no equipment entry, still goes through
  /// the free-text field above.
  Future<void> _chooseCylinder(
    BuildContext context,
    AppSettings settings,
  ) async {
    final picked = await pickBlenderCylinderSpecs(context, ref);
    if (picked == null) return;
    final litres = picked.volumeL;
    ref.read(blenderCylinderLitersProvider.notifier).state = litres;
    _cylinder.text = formatRoundedForInput(
      litersToDisplayVolume(litres, settings),
      2,
    );
    saveBlenderPreferences(ref);
  }

  static const List<int> _costFlex = [4, 4, 4, 4];

  /// Units in a header row rather than repeated after every gas (issue #1876
  /// follow-up), on the same flexible `Row`/`Expanded` grid the values below
  /// it use so the columns compress in place on a narrow screen.
  Widget _costTable(
    BuildContext context,
    List<GasCostLine> lines,
    UnitFormatter units,
    AppSettings settings,
    String currency,
    int decimals,
  ) {
    final headerStyle = blenderTableHeaderStyle(context);
    final valueStyle = blenderTableValueStyle(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: _costFlex[0],
              child: Text(
                context.l10n.gasCalculators_blender_flushFeeColumnGas,
                style: headerStyle,
              ),
            ),
            Expanded(
              flex: _costFlex[1],
              child: Text(
                '${context.l10n.gasCalculators_blender_stepColumnAdded} '
                '(${units.pressureSymbol})',
                style: headerStyle,
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              flex: _costFlex[2],
              child: Text(
                units.volumeSymbol,
                style: headerStyle,
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              flex: _costFlex[3],
              child: Text(
                currency,
                style: headerStyle,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final line in lines)
          _costLine(context, line, units, currency, decimals, valueStyle),
      ],
    );
  }

  Widget _costLine(
    BuildContext context,
    GasCostLine line,
    UnitFormatter units,
    String currency,
    int decimals,
    TextStyle? style,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: _costFlex[0],
            child: Text(formatPreciseGasName(context, line.gas), style: style),
          ),
          Expanded(
            flex: _costFlex[1],
            child: Text(
              '+${units.formatPressureValue(line.addedBar, decimals: decimals)}',
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: _costFlex[2],
            child: Text(
              // formatVolumeValue converts litres to the diver's unit itself.
              // Converting first made a cubic-foot diver's column read zero.
              units.formatVolumeValue(line.freeGasLiters),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: _costFlex[3],
            child: Text(
              line.cost == null ? '' : formatFixedForInput(line.cost!, 2),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalLine(
    BuildContext context,
    BillingResult billing,
    String currency,
  ) {
    final textTheme = Theme.of(context).textTheme;
    if (billing.total == null) {
      return Text(
        context.l10n.gasCalculators_blender_costMissingPrice,
        style: textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          context.l10n.gasCalculators_blender_costTotal,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          formatMoney(billing.total!, currency),
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// The hose-purge flat fee: whether it is charged, how often it appears on
  /// the bill, and each gas's volume and price, both entered on the Fill
  /// gases settings card and shown here as read-only text (issue #42
  /// follow-up). The bill itself reads the same setting for its own,
  /// likewise read-only, line.
  Widget _flushFeeSettings(
    BuildContext context,
    AppSettings settings,
    UnitFormatter units,
    String currency,
  ) {
    final enabled = ref.watch(blenderFlushFeeEnabledProvider);
    final mode = ref.watch(blenderFlushFeeModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('blender-flush-fee-enabled'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(context.l10n.gasCalculators_blender_flushFeeEnable),
          value: enabled,
          onChanged: (value) {
            ref.read(blenderFlushFeeEnabledProvider.notifier).state = value;
            saveBlenderPreferences(ref);
          },
        ),
        if (enabled) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SegmentedButton<FlushFeeMode>(
              key: const Key('blender-flush-fee-mode'),
              segments: [
                ButtonSegment(
                  value: FlushFeeMode.perInvoice,
                  label: Text(
                    context.l10n.gasCalculators_blender_flushFeeModePerInvoice,
                  ),
                ),
                ButtonSegment(
                  value: FlushFeeMode.perFill,
                  label: Text(
                    context.l10n.gasCalculators_blender_flushFeeModePerFill,
                  ),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) {
                ref.read(blenderFlushFeeModeProvider.notifier).state =
                    selection.first;
                saveBlenderPreferences(ref);
              },
            ),
          ),
          _flushFeeTable(context, ref, settings, units, currency),
        ],
      ],
    );
  }

  /// Every gas's purge volume and rate on the same `_costFlex` grid the cost
  /// table below it uses (issue #1876 follow-up): gas in column 1, column 2
  /// left blank since a flush has no "added bar" of its own, volume in
  /// column 3, rate in column 4 -- so both tables' columns share one set of
  /// edges. Units sit in a header row rather than repeated per cell, so
  /// narrow screens compress the columns in place instead of overflowing
  /// off-screen the way `DataTable`'s fixed widths did. Both figures are
  /// entered once, next to their bank on the Fill gases settings card, and
  /// shown here as plain text rather than a second, easily-drifting entry
  /// point for the same numbers.
  Widget _flushFeeTable(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    UnitFormatter units,
    String currency,
  ) {
    final prices = ref.watch(blenderGasPricesProvider);
    final flushGases = ref.watch(blenderFlushFeeGasesProvider);
    final headerStyle = blenderTableHeaderStyle(context);
    final valueStyle = blenderTableValueStyle(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: _costFlex[0],
              child: Text(
                context.l10n.gasCalculators_blender_flushFeeColumnGas,
                style: headerStyle,
              ),
            ),
            Expanded(flex: _costFlex[1], child: const SizedBox()),
            Expanded(
              flex: _costFlex[2],
              child: Text(
                units.volumeSymbol,
                style: headerStyle,
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              flex: _costFlex[3],
              child: Text(
                '$currency/100${units.volumeSymbol}',
                style: headerStyle,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < BlenderGasRole.values.length; i++)
          _flushFeeGasRow(
            context,
            BlenderGasRole.values[i],
            settings,
            flushGases[i].volumeLiters,
            prices[i],
            valueStyle,
          ),
      ],
    );
  }

  Widget _flushFeeGasRow(
    BuildContext context,
    BlenderGasRole role,
    AppSettings settings,
    double volumeLiters,
    double? price,
    TextStyle? style,
  ) {
    return Padding(
      key: Key('blender-flush-fee-row-${role.name}'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: _costFlex[0],
            child: Text(blenderGasRoleLabel(context, role), style: style),
          ),
          Expanded(flex: _costFlex[1], child: const SizedBox()),
          Expanded(
            flex: _costFlex[2],
            child: Text(
              formatRoundedForInput(
                litersToDisplayVolume(volumeLiters, settings),
                2,
              ),
              key: Key('blender-flush-fee-volume-${role.name}'),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: _costFlex[3],
            child: Text(
              price == null
                  ? ''
                  : formatRoundedForInput(
                      pricePer100LitersToDisplay(price, settings),
                      2,
                    ),
              key: Key('blender-flush-fee-price-${role.name}'),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
