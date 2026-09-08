import 'dart:ui' as ui show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_gas_role.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/blending/flush_fee.dart';
import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_billed_line_row.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_formatting.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_invoice_export_sheet.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_section_title.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_volume_conversion.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// The running bill for a blending session.
///
/// A fill station rarely does one cylinder. Without this the blender has to
/// write each finished fill down on paper before starting the next, because
/// the next blend replaces the one on screen (issue #1100).
class BlenderInvoiceCard extends ConsumerStatefulWidget {
  const BlenderInvoiceCard({super.key});

  @override
  ConsumerState<BlenderInvoiceCard> createState() => _BlenderInvoiceCardState();
}

class _BlenderInvoiceCardState extends ConsumerState<BlenderInvoiceCard> {
  late final TextEditingController _billedTo;

  /// The logbook name is a starting point, offered once. Re-seeding on every
  /// rebuild would fight the diver as they typed a customer's name.
  bool _seededBilledTo = false;

  /// Wraps the whole card for the "Export as Image" option, so it captures
  /// exactly what the diver is already looking at.
  final _exportBoundaryKey = GlobalKey();

  /// True while an export chosen from [BlenderInvoiceExportSheet] is
  /// running. Drives the export button's spinner; the export itself only
  /// starts once that sheet has fully closed (see [_openExportSheet]).
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _billedTo = TextEditingController(text: ref.read(blenderBilledToProvider));
  }

  @override
  void dispose() {
    _billedTo.dispose();
    super.dispose();
  }

  /// Fill in [name] the first time one is available and the field is still
  /// untouched. Scheduled off the build because it writes provider state.
  void _seedBilledTo(String name) {
    if (name.isEmpty || _seededBilledTo) return;
    if (ref.read(blenderBilledToProvider).isNotEmpty) {
      _seededBilledTo = true;
      return;
    }
    _seededBilledTo = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(blenderBilledToProvider).isNotEmpty) return;
      ref.read(blenderBilledToProvider.notifier).state = name;
      _billedTo.text = name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fills = ref.watch(blenderBilledFillsProvider);
    final currency = ref.watch(blenderCurrencyProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final decimals = pressureDecimalsFor(settings.pressureUnit);
    final billedDate = ref.watch(blenderBilledDateProvider);
    final theme = Theme.of(context);

    final flushEnabled = ref.watch(blenderFlushFeeEnabledProvider);
    final flushMode = ref.watch(blenderFlushFeeModeProvider);
    final flushGases = ref.watch(blenderFlushFeeGasesProvider);
    final gasPrices = ref.watch(blenderGasPricesProvider);
    // "Once per bill" always shows once the fee is on, even before the first
    // fill: it is a session setup cost, not tied to any one cylinder. "Once
    // per fill" has nothing to charge yet when nothing has been filled.
    final flushMultiplier = flushFeeMultiplier(
      mode: flushMode,
      fillCount: fills.length,
    );
    final showFlush = flushEnabled && flushMultiplier > 0;

    // The one place the fee becomes money. Displayed, totalled, archived and
    // exported from the same lines, so those four cannot disagree about what
    // was charged (PR #1359 review).
    final flushFills = _flushFills(
      context,
      enabled: flushEnabled,
      mode: flushMode,
      fillCount: fills.length,
      gases: flushGases,
      gasPrices: gasPrices,
    );
    final total = totalOf([...fills, ...flushFills]);

    // Seed the name from the logbook, once, and only when the diver has not
    // typed one. A fill station fills other people's cylinders, so this is a
    // starting point rather than a fixed label.
    //
    // Watched, not listened to: currentDiverProvider is resolved long before
    // anyone opens the calculators tab, and ref.listen fires only on a later
    // change, so the listener never ran in the real app (PR #1215 review).
    final diver = ref.watch(currentDiverProvider).valueOrNull;
    _seedBilledTo(diver?.name.trim() ?? '');

    return RepaintBoundary(
      key: _exportBoundaryKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dateHeader(context, billedDate, settings),
              _tariffSummary(context, settings, currency),
              TextField(
                controller: _billedTo,
                decoration: InputDecoration(
                  labelText: context.l10n.gasCalculators_blender_billedTo,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    ref.read(blenderBilledToProvider.notifier).state = v,
                onEditingComplete: () => saveBlenderPreferences(ref),
                onSubmitted: (_) => saveBlenderPreferences(ref),
              ),
              const SizedBox(height: 16),
              if (fills.isEmpty && !showFlush)
                Text(
                  context.l10n.gasCalculators_blender_billedNone,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else ...[
                if (showFlush) ...[
                  // Names the billing mode in effect, so a diver reading the
                  // bill can tell at a glance whether the flush fee below was
                  // charged once for the whole invoice or once per fill,
                  // rather than having to reopen the Cost card to check.
                  Text(
                    flushMode == FlushFeeMode.perInvoice
                        ? context
                              .l10n
                              .gasCalculators_blender_flushFeeModePerInvoice
                        : context
                              .l10n
                              .gasCalculators_blender_flushFeeModePerFill,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (var i = 0; i < BlenderGasRole.values.length; i++)
                    _flushFeeLine(
                      context,
                      i,
                      flushGases[i],
                      flushMultiplier,
                      currency,
                      units,
                      settings,
                    ),
                  const SizedBox(height: 4),
                ],
                for (final f in fills)
                  _fillLine(context, f, currency, units, decimals),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('blender-add-manual-line'),
                onPressed: () => _editLine(null),
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.l10n.gasCalculators_blender_addManualLine),
              ),
              if (fills.isNotEmpty || showFlush) ...[
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.gasCalculators_blender_billedTotal,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      formatMoney(total.amount, currency),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (!total.complete)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      context.l10n.gasCalculators_blender_billedIncomplete,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                // A Wrap so the two actions drop to separate lines on the
                // narrowest phone rather than overflowing.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('blender-export'),
                      onPressed: _isExporting
                          ? null
                          : () => _openExportSheet(
                              context,
                              [...fills, ...flushFills],
                              currency,
                              units,
                              decimals,
                              billedDate,
                              total,
                            ),
                      icon: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.ios_share, size: 18),
                      label: Text(context.l10n.gasCalculators_blender_export),
                    ),
                    FilledButton.icon(
                      key: const Key('blender-pay'),
                      onPressed: _confirmPay,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(context.l10n.gasCalculators_blender_pay),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateHeader(
    BuildContext context,
    DateTime date,
    AppSettings settings,
  ) {
    final units = UnitFormatter(settings);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: BlenderSectionTitle(
              context.l10n.gasCalculators_blender_billedDate(
                units.formatDate(date),
              ),
            ),
          ),
          IconButton(
            key: const Key('blender-invoice-archive'),
            icon: const Icon(Icons.history, size: 20),
            visualDensity: VisualDensity.compact,
            tooltip: context.l10n.gasCalculators_blender_invoiceArchive,
            onPressed: () => context.push(kBlenderInvoiceArchiveRoute),
          ),
          IconButton(
            key: const Key('blender-billed-date-edit'),
            icon: const Icon(Icons.edit_calendar_outlined, size: 20),
            visualDensity: VisualDensity.compact,
            tooltip: context.l10n.gasCalculators_blender_billedDateEdit,
            onPressed: () => _pickDate(context, date, settings),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    DateTime current,
    AppSettings settings,
  ) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      dateFormat: settings.dateFormat,
    );
    if (picked == null) return;
    ref.read(blenderBilledDateProvider.notifier).state = picked;
    saveBlenderPreferences(ref);
  }

  /// The gas tariff, so it can be checked at a glance without switching to
  /// the "Cost" card. Zipped by role against the gas that role *currently*
  /// holds, matching how the price fields there are labelled - not by
  /// grouping historical invoice lines, which may have been filled under a
  /// fill order since reconfigured (PR #1215 review). Keying by role rather
  /// than by bank position keeps this correct however the fill order is
  /// arranged (issue #42).
  Widget _tariffSummary(
    BuildContext context,
    AppSettings settings,
    String currency,
  ) {
    final topupO2 = ref.watch(blenderTopupO2PercentProvider);
    final prices = ref.watch(blenderGasPricesProvider);
    final units = UnitFormatter(settings);
    final parts = <String>[];
    for (final role in BlenderGasRole.values) {
      final price = prices[role.index];
      if (price == null) continue;
      final display = pricePer100LitersToDisplay(price, settings);
      parts.add(
        '${formatPreciseGasName(context, gasForRole(role, topupO2))} '
        '${formatMoney(display, currency)}/100${units.volumeSymbol}',
      );
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        '${context.l10n.gasCalculators_blender_tariff}: ${parts.join('  ·  ')}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// [fills] is the whole bill, hose purges included: an exported invoice
  /// itemises everything its total charges for.
  Future<void> _openExportSheet(
    BuildContext context,
    List<BilledFill> fills,
    String currency,
    UnitFormatter units,
    int decimals,
    DateTime billedDate,
    BilledTotal total,
  ) async {
    final settings = ref.read(settingsProvider);
    final topupO2 = ref.read(blenderTopupO2PercentProvider);
    final prices = ref.read(blenderGasPricesProvider);
    final tariffParts = <String>[];
    for (final role in BlenderGasRole.values) {
      final price = prices[role.index];
      if (price == null) continue;
      final display = pricePer100LitersToDisplay(price, settings);
      tariffParts.add(
        '${formatPreciseGasName(context, gasForRole(role, topupO2))} '
        '${formatMoney(display, currency)}/100${units.volumeSymbol}',
      );
    }

    final data = BlenderInvoiceExportData(
      date: context.l10n.gasCalculators_blender_billedDate(
        units.formatDate(billedDate),
      ),
      billedTo: ref.read(blenderBilledToProvider),
      tariff: tariffParts.join('  ·  '),
      fills: [
        for (final fill in fills)
          BlenderInvoiceExportFill(
            label: fill.label,
            total: fill.total == null ? '' : formatMoney(fill.total!, currency),
            lines: [
              for (final line in fill.lines)
                BlenderInvoiceExportLine(
                  gas: line.gas,
                  volume: line.freeGasLiters != null
                      ? units.formatVolume(line.freeGasLiters)
                      : units.formatPressure(line.addedBar, decimals: decimals),
                  cost: line.cost == null
                      ? ''
                      : formatMoney(line.cost!, currency),
                ),
            ],
          ),
      ],
      total: total.complete ? formatMoney(total.amount, currency) : '',
      incomplete: !total.complete,
    );

    final choice =
        await showModalBottomSheet<(BlenderInvoiceExportFormat, Rect?)>(
          context: context,
          isScrollControlled: true,
          builder: (context) => const BlenderInvoiceExportSheet(),
        );
    if (choice == null) return;
    await _runExport(choice.$1, data, choice.$2);
  }

  /// Runs the export chosen from [BlenderInvoiceExportSheet].
  ///
  /// Started only after that sheet has fully closed: opening the OS share
  /// sheet while it was still mounted and mid-transition made the native
  /// chooser fail to list any targets ("not all sharing methods could be
  /// displayed", issue #44) - the same reason the dive profile export sheet
  /// on the dive detail page pops before it shares.
  ///
  /// The pop alone was not enough on Windows: the sheet's closing route
  /// transition still owns window focus for a moment afterwards, and
  /// `DataTransferManager.ShowShareUIForWindow` fails with that same "not
  /// all sharing methods" error when invoked before focus returns to the
  /// main window. The dive profile export on the dive detail page waits a
  /// frame the same way before it shares (issue #44 follow-up).
  Future<void> _runExport(
    BlenderInvoiceExportFormat format,
    BlenderInvoiceExportData data,
    Rect? anchor,
  ) async {
    setState(() => _isExporting = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      switch (format) {
        case BlenderInvoiceExportFormat.pdf:
          await ExportService().exportBlenderInvoiceToPdf(
            data,
            sharePositionOrigin: anchor,
          );
        case BlenderInvoiceExportFormat.excel:
          await ExportService().exportBlenderInvoiceToExcel(
            data,
            sharePositionOrigin: anchor,
          );
        case BlenderInvoiceExportFormat.image:
          final boundary =
              _exportBoundaryKey.currentContext?.findRenderObject()
                  as RenderRepaintBoundary?;
          if (boundary == null) {
            throw StateError('invoice card is not on screen');
          }
          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (byteData == null) {
            throw StateError('failed to encode invoice image');
          }
          await ExportService().exportImageAsPng(
            byteData.buffer.asUint8List(),
            'submersion_blender_invoice_${DateTime.now().millisecondsSinceEpoch}.png',
            sharePositionOrigin: anchor,
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.gasCalculators_blender_exportError('$e'),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// One structured flush-fee line: the gas, its purge volume, and what that
  /// volume costs at the configured rate. Derived from settings rather than
  /// stored in [blenderBilledFillsProvider] — nothing in that append-only
  /// list is "first" by construction, so a fee meant to sit once at the top
  /// of the bill has to live outside it (issue #1335).
  Widget _flushFeeLine(
    BuildContext context,
    int index,
    FlushFeeGasSetting gas,
    int multiplier,
    String currency,
    UnitFormatter units,
    AppSettings settings,
  ) {
    final role = BlenderGasRole.values[index];
    final label = blenderGasRoleLabel(context, role);
    final price = ref.watch(blenderGasPricesProvider)[role.index];
    final cost = flushFeeCost(gas.volumeLiters * multiplier, price);
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              multiplier > 1 ? '$label  ×$multiplier' : label,
              style: style,
            ),
          ),
          // Read-only: this role's flush volume is entered once, on the Fill
          // gases settings card (blender_fill_gases_card.dart), next to its
          // price, and shown here as plain text rather than a second,
          // easily-drifting entry point for the same number (issue #42
          // follow-up). Plain text, not a disabled-looking field: an
          // InputDecorator still reads as an inert input control (issue #44
          // follow-up).
          SizedBox(
            width: 72,
            child: Text(
              '${formatRoundedForInput(litersToDisplayVolume(gas.volumeLiters, settings), 2)} '
              '${units.volumeSymbol}',
              key: Key('blender-flush-fee-liters-${role.name}'),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              cost == null ? '' : formatMoney(cost, currency),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fillLine(
    BuildContext context,
    BilledFill fill,
    String currency,
    UnitFormatter units,
    int decimals,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  fill.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  fill.total == null ? '' : formatMoney(fill.total!, currency),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Compact so a label, an amount and two actions still fit the
              // narrowest phone the app supports.
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: context.l10n.gasCalculators_blender_editLine(
                  fill.label,
                ),
                onPressed: () => _editLine(fill),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: context.l10n.gasCalculators_blender_deleteLine(
                  fill.label,
                ),
                onPressed: () => _delete(fill),
              ),
            ],
          ),
          // The itemisation is what makes the total checkable at the counter,
          // so it stays visible rather than hiding behind a disclosure.
          for (final line in fill.lines)
            BlenderBilledLineRow(
              line: line,
              currency: currency,
              units: units,
              decimals: decimals,
            ),
          if (fill.customMix case final mix?)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text(
                '${units.formatVolume(mix.cylinderLiters)} · '
                '${formatPreciseMix(context, GasMix(o2: mix.o2, he: mix.he))}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// [flushFeeFills] with this app's labels attached.
  ///
  /// The label has to stand on its own here, unlike the live display's
  /// [_flushFeeLine], which sits under a heading naming the billing mode: an
  /// archived or exported line is read months later with no such context, so
  /// it says "hose purge" rather than just the gas.
  List<BilledFill> _flushFills(
    BuildContext context, {
    required bool enabled,
    required FlushFeeMode mode,
    required int fillCount,
    required List<FlushFeeGasSetting> gases,
    required List<double?> gasPrices,
  }) => flushFeeFills(
    enabled: enabled,
    mode: mode,
    fillCount: fillCount,
    gases: gases,
    pricesPer100: gasPrices,
    labelFor: (role) => context.l10n.gasCalculators_blender_flushFeeLine(
      blenderGasRoleLabel(context, role),
    ),
  );

  /// [_flushFills] for the bill as it stands right now.
  ///
  /// Reads rather than watches: both callers run from a button, after the
  /// frame that decided what is on the bill.
  List<BilledFill> _currentFlushFills(BuildContext context, int fillCount) =>
      _flushFills(
        context,
        enabled: ref.read(blenderFlushFeeEnabledProvider),
        mode: ref.read(blenderFlushFeeModeProvider),
        fillCount: fillCount,
        gases: ref.read(blenderFlushFeeGasesProvider),
        gasPrices: ref.read(blenderGasPricesProvider),
      );

  void _delete(BilledFill fill) {
    ref.read(blenderBilledFillsProvider.notifier).state = [
      ...ref.read(blenderBilledFillsProvider).where((f) => f.id != fill.id),
    ];
    saveBlenderPreferences(ref);
  }

  /// Edit an existing line, or add a manual one when [fill] is null.
  ///
  /// The amount stays editable on computed fills too: rounding and the
  /// occasional discount happen at a real counter, and re-blending the
  /// cylinder to change what it costs would be absurd.
  Future<void> _editLine(BilledFill? fill) async {
    final edited = await showModalBottomSheet<_LineEdit>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LineEditSheet(fill: fill),
    );
    if (edited == null) return;

    final fills = ref.read(blenderBilledFillsProvider);
    if (fill == null) {
      ref.read(blenderBilledFillsProvider.notifier).state = appendCapped(
        fills,
        BilledFill(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          label: edited.label,
          lines: const [],
          total: edited.amount,
          customMix: edited.customMix,
        ),
      );
    } else {
      ref.read(blenderBilledFillsProvider.notifier).state = [
        for (final f in fills)
          if (f.id == fill.id)
            f.copyWith(
              label: edited.label,
              total: edited.amount,
              clearTotal: edited.amount == null,
              customMix: edited.customMix,
              clearCustomMix: edited.customMix == null,
            )
          else
            f,
      ];
    }
    saveBlenderPreferences(ref);
  }

  /// Archives the running bill and starts a fresh one.
  ///
  /// Replaces the old "Clear" action rather than sitting beside it: a bill
  /// that is only cleared, never archived, is the exact history gap issue
  /// #22 (a full invoice archive view) would otherwise have to backfill from
  /// nothing. The confirmation dialog is kept, since paying is just as
  /// destructive to the running bill as clearing was.
  Future<void> _confirmPay() async {
    final fills = ref.read(blenderBilledFillsProvider);
    final count = fills.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.gasCalculators_blender_payTitle),
        content: Text(context.l10n.gasCalculators_blender_payBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_action_close),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.gasCalculators_blender_pay),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Archived with the purge lines materialised into it, not merely counted
    // in the total: the fee is derived from settings that go on changing, so
    // a bill that stored only the number could never be itemised again
    // (PR #1359 review).
    final billed = [...fills, ..._currentFlushFills(context, fills.length)];
    final total = totalOf(billed);
    final archived = ArchivedInvoice(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: ref.read(blenderBilledDateProvider),
      billedTo: ref.read(blenderBilledToProvider),
      fills: billed,
      total: total.complete ? total.amount : null,
      currencyCode: ref.read(blenderCurrencyProvider),
    );
    ref
        .read(blenderArchivedInvoicesProvider.notifier)
        .state = appendArchivedCapped(
      ref.read(blenderArchivedInvoicesProvider),
      archived,
    );
    ref.read(blenderBilledFillsProvider.notifier).state = const [];
    ref.read(blenderBilledDateProvider.notifier).state = DateTime.now();
    saveBlenderPreferences(ref);
  }
}

/// What the edit sheet hands back.
class _LineEdit {
  const _LineEdit({required this.label, required this.amount, this.customMix});
  final String label;
  final double? amount;
  final BilledCustomMix? customMix;
}

/// Owns its own controllers, and disposes them in its own State.
///
/// Creating them in the caller and disposing on the sheet's future looks
/// equivalent and is not: the future completes when the route is popped, while
/// the exit transition keeps rebuilding these fields for several more frames
/// against a controller that is already gone.
///
/// A scrollable, keyboard-aware bottom sheet rather than the fixed-size
/// `AlertDialog` this replaced: a cylinder row and an O2/He row roughly
/// double the field count, and a taller fixed dialog risks overflow once the
/// keyboard is up on the narrowest phone the app supports (issue #1335).
class _LineEditSheet extends ConsumerStatefulWidget {
  const _LineEditSheet({required this.fill});

  final BilledFill? fill;

  @override
  ConsumerState<_LineEditSheet> createState() => _LineEditSheetState();
}

class _LineEditSheetState extends ConsumerState<_LineEditSheet> {
  late final TextEditingController _label;
  late final TextEditingController _amount;
  late final TextEditingController _cylinder;
  late final TextEditingController _o2;
  late final TextEditingController _he;

  /// Only a new line or one that is still a manual/custom-mix entry offers
  /// the cylinder and mix fields. A computed fill's gases are already
  /// itemised in [BilledFill.lines]; editing them here would let the label
  /// and the itemisation disagree.
  bool get _showMix => widget.fill == null || widget.fill!.isManual;

  String? _error;

  @override
  void initState() {
    super.initState();
    final fill = widget.fill;
    final settings = ref.read(settingsProvider);
    _label = TextEditingController(text: fill?.label ?? '');
    _amount = TextEditingController(
      text: fill?.total == null ? '' : formatRoundedForInput(fill!.total!, 2),
    );
    final mix = fill?.customMix;
    final double cylinderLiters =
        mix?.cylinderLiters ?? ref.read(blenderCylinderLitersProvider);
    _cylinder = TextEditingController(
      text: formatRoundedForInput(
        litersToDisplayVolume(cylinderLiters, settings),
        2,
      ),
    );
    _o2 = TextEditingController(text: formatRoundedForInput(mix?.o2 ?? 21, 1));
    _he = TextEditingController(text: formatRoundedForInput(mix?.he ?? 0, 1));
  }

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _cylinder.dispose();
    _o2.dispose();
    _he.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _label.text.trim();
    final amount = parseUserDecimal(_amount.text);
    BilledCustomMix? customMix;
    if (_showMix) {
      final settings = ref.read(settingsProvider);
      final liters = parseUserDecimal(_cylinder.text);
      final o2 = parseUserDecimal(_o2.text);
      final he = parseUserDecimal(_he.text);
      if (liters != null && o2 != null && he != null) {
        if (!MixTemplate(o2: o2, he: he).isValid) {
          setState(
            () => _error = context.l10n.gasCalculators_blender_error_invalidMix,
          );
          return;
        }
        customMix = BilledCustomMix(
          cylinderLiters: displayVolumeToLiters(liters, settings),
          o2: o2,
          he: he,
        );
      }
    }
    final effectiveLabel = label.isNotEmpty
        ? label
        : customMix != null
        ? formatPreciseMix(context, GasMix(o2: customMix.o2, he: customMix.he))
        : '';
    // Nothing to name the line with. Said out loud rather than returned on
    // quietly: a Save that does nothing and explains nothing reads as a
    // broken button (PR #1359 review), the same reasoning MixTemplateManager
    // applies to a half-typed mix.
    if (effectiveLabel.isEmpty) {
      setState(
        () => _error = context.l10n.gasCalculators_blender_lineNeedsDescription,
      );
      return;
    }
    Navigator.of(context).pop(
      _LineEdit(label: effectiveLabel, amount: amount, customMix: customMix),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.fill;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              fill == null
                  ? context.l10n.gasCalculators_blender_addManualLine
                  : context.l10n.gasCalculators_blender_editLine(fill.label),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('blender-line-description'),
              controller: _label,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.gasCalculators_blender_lineDescription,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_showMix) ...[
              _cylinderRow(context, settings, units),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      context,
                      _o2,
                      context.l10n.gasCalculators_blender_o2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _numberField(
                      context,
                      _he,
                      context.l10n.gasCalculators_blender_he,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const Key('blender-line-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: context.l10n.gasCalculators_blender_lineAmount,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(context.l10n.common_action_save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cylinderRow(
    BuildContext context,
    AppSettings settings,
    UnitFormatter units,
  ) {
    // Sourced from the diver's global tank presets (issue #1335 follow-up),
    // same as BlenderBillingCard._cylinderRow: the blender keeps no cylinder
    // vault of its own, so this sheet's picker reads the same list.
    final presetsAsync = ref.watch(tankPresetsProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const Key('blender-line-cylinder'),
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
          ),
        ),
        const SizedBox(width: 8),
        presetsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (error, stackTrace) => IconButton(
            icon: const Icon(Icons.error_outline),
            tooltip: context.l10n.gasCalculators_blender_cylinderPresets,
            onPressed: null,
          ),
          data: (presets) => PopupMenuButton<double>(
            key: const Key('blender-line-cylinder-presets'),
            tooltip: context.l10n.gasCalculators_blender_cylinderPresets,
            position: PopupMenuPosition.under,
            itemBuilder: (context) => [
              for (final preset in presets)
                PopupMenuItem<double>(
                  value: preset.volumeLiters,
                  child: Text(
                    '${preset.displayName} '
                    '(${units.formatTankVolume(preset.volumeLiters, null)})',
                  ),
                ),
            ],
            onSelected: (liters) => setState(
              () => _cylinder.text = formatRoundedForInput(
                litersToDisplayVolume(liters, settings),
                2,
              ),
            ),
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
        ),
      ],
    );
  }

  Widget _numberField(
    BuildContext context,
    TextEditingController controller,
    String label,
  ) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: '$label (%)',
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
