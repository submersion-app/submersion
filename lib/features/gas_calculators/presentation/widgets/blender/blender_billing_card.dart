import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blend_billing.dart';
import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_formatting.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_section_title.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Cubic feet in a litre, matching `VolumeUnit.convert`.
///
/// Storage is canonical: litres for volumes, currency per 100 litres for
/// prices. Every conversion to and from the diver's unit happens at the text
/// field, and nowhere else. Adding a second conversion path is what let the
/// volume column convert twice while the price never converted at all
/// (PR #1215 review).
const double _cubicFeetPerLiter = 0.0353147;

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
  late final List<TextEditingController> _prices;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    final liters = ref.read(blenderCylinderLitersProvider);
    _cylinder = TextEditingController(
      text: formatRoundedForInput(_toDisplayVolume(liters, settings), 2),
    );
    _prices = [
      for (final p in ref.read(blenderGasPricesProvider))
        TextEditingController(
          text: p == null
              ? ''
              : formatRoundedForInput(_toDisplayPrice(p, settings), 2),
        ),
    ];
  }

  @override
  void dispose() {
    _cylinder.dispose();
    for (final c in _prices) {
      c.dispose();
    }
    super.dispose();
  }

  static bool _metric(AppSettings s) => s.volumeUnit == VolumeUnit.liters;

  /// Litres to the diver's volume unit, for seeding the cylinder field.
  static double _toDisplayVolume(double liters, AppSettings s) =>
      _metric(s) ? liters : liters * _cubicFeetPerLiter;

  static double _toLiters(double shown, AppSettings s) =>
      _metric(s) ? shown : shown / _cubicFeetPerLiter;

  /// A price per 100 litres, shown as a price per 100 of the diver's unit.
  ///
  /// Gas priced at 7.99 per 100 cu ft is 0.28 per 100 L: the same gas, the
  /// same money, a unit that is 28 times larger. Storing the entered number
  /// without this conversion charged a cubic-foot diver 28 times over.
  static double _toDisplayPrice(double per100Liters, AppSettings s) =>
      _metric(s) ? per100Liters : per100Liters / _cubicFeetPerLiter;

  static double _toPricePer100Liters(double shown, AppSettings s) =>
      _metric(s) ? shown : shown * _cubicFeetPerLiter;

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
            // A Wrap rather than a Row: the heading and the action together
            // are a few pixels too wide for the narrowest phone, and dropping
            // the button to its own line reads better than truncating it.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                BlenderSectionTitle(
                  context.l10n.gasCalculators_blender_billing,
                ),
                if (billing.lines.isNotEmpty)
                  TextButton.icon(
                    key: const Key('blender-save-fill'),
                    onPressed: () => _saveFill(context, billing, currency),
                    icon: const Icon(Icons.playlist_add, size: 18),
                    label: Text(context.l10n.gasCalculators_blender_saveFill),
                  ),
              ],
            ),
            _cylinderRow(context, settings, units),
            const SizedBox(height: 16),
            _currencyField(context, currency),
            const SizedBox(height: 16),
            // One field per configured bank, always, rather than one per
            // step of this particular blend. A blend that skips a bank would
            // otherwise slide the labels along and charge the next gas at the
            // wrong rate (PR #1215 review), and prices belong to the banks
            // anyway, not to today's fill.
            for (var slot = 0; slot < 3; slot++) ...[
              if (slot > 0) const SizedBox(height: 12),
              _priceField(context, slot, units),
            ],
            if (billing.lines.isNotEmpty) ...[
              const Divider(height: 28),
              for (final line in billing.lines)
                _costLine(context, line, units, settings, currency, decimals),
              const Divider(height: 20),
              _totalLine(context, billing, currency),
              const SizedBox(height: 8),
              Text(
                context.l10n.gasCalculators_blender_costBasis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final fill = BilledFill(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: label,
      lines: [
        for (final line in billing.lines)
          BilledGasLine(
            gas: formatPreciseGasName(context, line.gas),
            addedBar: line.addedBar,
            cost: line.cost,
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
    // The blending-bench list, not the dive-planning one: the same presets
    // serve both unit systems because formatTankVolume renders them in the
    // diver's own unit (issue #1100 review).
    final choices = blenderTankChoices();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _cylinder,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText:
                  '${context.l10n.gasCalculators_blender_cylinderVolume} '
                  '(${units.volumeSymbol})',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) =>
                ref.read(blenderCylinderLitersProvider.notifier).state =
                    _toLiters(parseUserDecimal(v) ?? 0, settings),
            onEditingComplete: () => saveBlenderPreferences(ref),
            onSubmitted: (_) => saveBlenderPreferences(ref),
          ),
        ),
        const SizedBox(width: 8),
        // A cubic-foot diver does not know their cylinder's water capacity in
        // cubic feet (an AL80 is 0.39), so the presets fill it for them.
        PopupMenuButton<TankSpec>(
          key: const Key('blender-cylinder-presets'),
          tooltip: context.l10n.gasCalculators_blender_cylinderPresets,
          position: PopupMenuPosition.under,
          itemBuilder: (context) => [
            for (final choice in choices)
              PopupMenuItem<TankSpec>(
                value: choice,
                child: Text(
                  units.formatTankVolume(
                    choice.waterVolumeLiters,
                    choice.workingPressureBar,
                    ratedCapacityCuft: choice.ratedCapacityCuft,
                  ),
                ),
              ),
          ],
          onSelected: (choice) {
            ref.read(blenderCylinderLitersProvider.notifier).state =
                choice.waterVolumeLiters;
            _cylinder.text = formatRoundedForInput(
              _toDisplayVolume(choice.waterVolumeLiters, settings),
              2,
            );
            saveBlenderPreferences(ref);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.gasCalculators_blender_cylinderPresets),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _currencyField(BuildContext context, String currency) {
    // Controlled so a stored currency arriving from the async preference load
    // moves the dropdown with it (PR #1215 review).
    return DropdownButtonFormField<String>(
      key: const Key('blender-currency'),
      initialValue: currency,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.l10n.gasCalculators_blender_currency,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final code in currencyCodesWith(currency))
          DropdownMenuItem(
            value: code,
            child: Text('$code  ${currencySymbol(code)}'),
          ),
      ],
      onChanged: (code) {
        if (code == null) return;
        ref.read(blenderCurrencyProvider.notifier).state = code;
        saveBlenderPreferences(ref);
      },
    );
  }

  Widget _priceField(BuildContext context, int slot, UnitFormatter units) {
    final gas = ref.watch(
      [
        blenderFillGas1Provider,
        blenderFillGas2Provider,
        blenderFillGas3Provider,
      ][slot],
    );
    return TextField(
      controller: _prices[slot],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText:
            '${formatPreciseGasName(context, gas)}  '
            '${context.l10n.gasCalculators_blender_unitPrice(units.volumeSymbol)}',
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) {
        final settings = ref.read(settingsProvider);
        ref.read(blenderGasPricesProvider.notifier).state = [
          for (final c in _prices)
            switch (parseUserDecimal(c.text)) {
              final double entered => _toPricePer100Liters(entered, settings),
              null => null,
            },
        ];
      },
      onEditingComplete: () => saveBlenderPreferences(ref),
      onSubmitted: (_) => saveBlenderPreferences(ref),
    );
  }

  Widget _costLine(
    BuildContext context,
    GasCostLine line,
    UnitFormatter units,
    AppSettings settings,
    String currency,
    int decimals,
  ) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(formatPreciseGasName(context, line.gas), style: style),
          ),
          Expanded(
            flex: 4,
            child: Text(
              '+${units.formatPressure(line.addedBar, decimals: decimals)}',
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              // formatVolume converts litres to the diver's unit itself.
              // Converting first made a cubic-foot diver's column read zero.
              units.formatVolume(line.freeGasLiters),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              line.cost == null ? '' : formatMoney(line.cost!, currency),
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
}
