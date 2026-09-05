import 'package:flutter/material.dart' show DateTimeRange;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blend_billing.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_gas_role.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/blending/flush_fee.dart';
import 'package:submersion/features/gas_calculators/domain/gas_blender.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Starting cylinder pressure (bar), read at the fill temperature. Zero means
/// an empty cylinder.
final blenderStartPressureProvider = StateProvider<double>((ref) => 0.0);

/// Mix already in the cylinder.
final blenderStartMixProvider = StateProvider<GasMix>(
  (ref) => const GasMix(o2: 21),
);

/// Desired final pressure (bar), once settled at the settled temperature.
final blenderTargetPressureProvider = StateProvider<double>((ref) => 200.0);

/// Desired final mix.
final blenderTargetMixProvider = StateProvider<GasMix>(
  (ref) => const GasMix(o2: 32),
);

/// The order the three fill-gas roles are applied in. See [BlenderGasRole];
/// the default O2 -> helium -> topup is the order a fill station works in:
/// helium is decanted while the cylinder is still low, and the compressor
/// tops off with the topup gas last. A helium-free target skips the helium
/// source and blends O2 with the topup gas.
final blenderFillOrderProvider = StateProvider<List<BlenderGasRole>>(
  (ref) => kDefaultBlenderFillOrder,
);

/// The topup role's oxygen fraction. The oxygen and helium roles are fixed at
/// 100% purity; only the topup role's mix is configurable (issue #42).
final blenderTopupO2PercentProvider = StateProvider<double>((ref) => 21.0);

/// The three fill gases resolved from [blenderFillOrderProvider] and
/// [blenderTopupO2PercentProvider], in solve order.
final blenderOrderedFillGasesProvider = Provider<List<GasMix>>((ref) {
  final order = ref.watch(blenderFillOrderProvider);
  final topupO2 = ref.watch(blenderTopupO2PercentProvider);
  return [for (final role in order) gasForRole(role, topupO2)];
});

/// [blenderGasPricesProvider], reordered to match
/// [blenderOrderedFillGasesProvider] so a blend step's positional
/// [BlendStep.fillGasIndex] still points at the right role's price however
/// the fill order is arranged (issue #42; formerly the documented #1215 bank-
/// skip bug's positional-index hazard, avoided here by never indexing
/// [blenderGasPricesProvider] itself by anything but role).
final blenderOrderedGasPricesProvider = Provider<List<double?>>((ref) {
  final order = ref.watch(blenderFillOrderProvider);
  final prices = ref.watch(blenderGasPricesProvider);
  return [for (final role in order) prices[role.index]];
});

/// Cylinder temperature while filling, in Celsius.
final blenderFillTempProvider = StateProvider<double>((ref) => kReferenceTempC);

/// Temperature the cylinder settles to afterwards, in Celsius.
final blenderSettledTempProvider = StateProvider<double>(
  (ref) => kReferenceTempC,
);

/// Which equation of state the blend is solved with.
final blenderGasModelProvider = StateProvider<BlendGasModel>(
  (ref) => BlendGasModel.zFactor,
);

/// Price per 100 litres of free gas, one entry per [BlenderGasRole] in that
/// enum's order. See [blenderOrderedGasPricesProvider] for the fill-order
/// projection the solver and billing actually consume.
final blenderGasPricesProvider = StateProvider<List<double?>>(
  (ref) => const [null, null, null],
);

/// Currency the prices are shown in. Always the diver's global default
/// (Settings -> Units -> Default currency): issue #1335 follow-up removes the
/// blender's own currency choice, so it can no longer drift from that setting.
final blenderCurrencyProvider = Provider<String>(
  (ref) => ref.watch(defaultCurrencyProvider),
);

/// Cylinder water capacity in litres, for costing only. Partial-pressure
/// mixing is driven by pressure and needs no cylinder.
final blenderCylinderLitersProvider = StateProvider<double>(
  (ref) => ref.read(settingsProvider).defaultTankVolume,
);

/// Saved target mixes.
final blenderTemplatesProvider = StateProvider<List<MixTemplate>>(
  (ref) => BlenderPreferences.seedTemplates,
);

/// Cylinders already finished and put on the bill, oldest first.
final blenderBilledFillsProvider = StateProvider<List<BilledFill>>(
  (ref) => const [],
);

/// Who the bill is for. Free text; the costing card seeds it from the
/// logbook's diver.
final blenderBilledToProvider = StateProvider<String>((ref) => '');

/// Whether a hose-purge flat fee is charged at all.
final blenderFlushFeeEnabledProvider = StateProvider<bool>((ref) => false);

/// How often the flush fee's lines appear on the bill.
final blenderFlushFeeModeProvider = StateProvider<FlushFeeMode>(
  (ref) => FlushFeeMode.perInvoice,
);

/// One entry per [BlenderGasRole], in that enum's order.
final blenderFlushFeeGasesProvider = StateProvider<List<FlushFeeGasSetting>>(
  (ref) => defaultFlushFeeGases,
);

/// When the running bill started. Defaults to today so the date is editable
/// from the moment a bill is open, not only once it is paid.
final blenderBilledDateProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);

/// Bills already paid and archived, oldest first.
final blenderArchivedInvoicesProvider = StateProvider<List<ArchivedInvoice>>(
  (ref) => const [],
);

/// The date range narrowing the invoice archive view. Ephemeral by design,
/// matching [preDiveSessionFilterProvider]: a filter is a view of the current
/// screen, not a stored preference, so it resets the next time the archive
/// is opened rather than persisting across sessions.
final blenderInvoiceArchiveFilterProvider = StateProvider<DateTimeRange?>(
  (ref) => null,
);

/// Archived invoices matching [blenderInvoiceArchiveFilterProvider], newest
/// first so a fill station checking "what did I just charge" does not have to
/// scroll past months of history.
final filteredBlenderArchivedInvoicesProvider = Provider<List<ArchivedInvoice>>(
  (ref) {
    final invoices = ref.watch(blenderArchivedInvoicesProvider);
    final range = ref.watch(blenderInvoiceArchiveFilterProvider);
    final filtered = range == null
        ? invoices
        : invoices
              .where((invoice) => _inDateRange(invoice.date, range))
              .toList();
    return filtered.reversed.toList();
  },
);

/// Whether [date] falls within [range], inclusive of the whole end day: the
/// picker yields whole days, so an invoice paid at 23:30 on the last selected
/// day must still match.
bool _inDateRange(DateTime date, DateTimeRange range) {
  final startOfFirstDay = DateTime(
    range.start.year,
    range.start.month,
    range.start.day,
  );
  final endOfLastDay = DateTime(
    range.end.year,
    range.end.month,
    range.end.day,
  ).add(const Duration(days: 1));
  return !date.isBefore(startOfFirstDay) && date.isBefore(endOfLastDay);
}

/// Bumped by a reset so the input fields re-seed their controllers.
final blenderResetEpochProvider = StateProvider<int>((ref) => 0);

/// Either a computed fill procedure or the reason one is not achievable.
class BlenderOutcome {
  const BlenderOutcome({this.result, this.error, this.drainToBar});
  final BlendResult? result;
  final BlendError? error;

  /// Set when the blend fails only because the cylinder holds too much gas:
  /// the pressure to drain down to before starting.
  final double? drainToBar;
}

/// The fill procedure for the current inputs; carries a [BlendError] instead of
/// throwing when the requested blend is impossible.
final blenderResultProvider = Provider<BlenderOutcome>((ref) {
  try {
    final gases = ref.watch(blenderOrderedFillGasesProvider);
    return BlenderOutcome(
      result: computeBlend(
        GasBlenderInputs(
          startPressureBar: ref.watch(blenderStartPressureProvider),
          start: ref.watch(blenderStartMixProvider),
          targetPressureBar: ref.watch(blenderTargetPressureProvider),
          target: ref.watch(blenderTargetMixProvider),
          fillGas1: gases[0],
          fillGas2: gases[1],
          fillGas3: gases[2],
          model: ref.watch(blenderGasModelProvider),
          fillTempC: ref.watch(blenderFillTempProvider),
          settledTempC: ref.watch(blenderSettledTempProvider),
        ),
      ),
    );
  } on BlendException catch (e) {
    return BlenderOutcome(error: e.error, drainToBar: e.drainToBar);
  }
});

/// What the current blend costs. Empty when there is no blend to price.
final blenderBillingProvider = Provider<BillingResult>((ref) {
  final blend = ref.watch(blenderResultProvider).result;
  if (blend == null) {
    return const BillingResult(lines: [], total: null);
  }
  return computeBlendCost(
    blend: blend,
    waterLiters: ref.watch(blenderCylinderLitersProvider),
    pricesPer100: ref.watch(blenderOrderedGasPricesProvider),
  );
});

/// Loads the saved preferences once and pushes them into the state providers.
///
/// A first run has no stored blob, which is exactly what seeds the default
/// templates. Deleting every template afterwards stores an empty list, and an
/// empty list is not an absent blob, so the deletion sticks.
// no-tick: a one-shot SEED with side effects, not a cached query. Re-running
// it rewrites every StateProvider the blender persists and bumps the reset
// epoch, so a tick from the blender's own save would re-seed every text field
// while the diver was still typing in it. The trade is deliberate and
// bounded: preferences changed on another device arrive on the next open of
// the calculator rather than mid-session, and nothing here renders a stale
// query result.
final blenderPreferencesLoaderProvider = FutureProvider<void>((ref) async {
  final stored = await ref
      .read(appSettingsRepositoryProvider)
      .getBlenderPreferences();
  if (stored == null) return;
  ref.read(blenderTemplatesProvider.notifier).state = stored.templates;
  ref.read(blenderGasPricesProvider.notifier).state = stored.gasPrices;
  ref.read(blenderFillTempProvider.notifier).state = stored.fillTempC;
  ref.read(blenderSettledTempProvider.notifier).state = stored.settledTempC;
  ref.read(blenderCylinderLitersProvider.notifier).state =
      stored.cylinderWaterLiters;
  ref.read(blenderGasModelProvider.notifier).state = stored.model;
  ref.read(blenderBilledFillsProvider.notifier).state = stored.billedFills;
  ref.read(blenderBilledToProvider.notifier).state = stored.billedTo;
  ref.read(blenderStartPressureProvider.notifier).state =
      stored.startPressureBar;
  ref.read(blenderStartMixProvider.notifier).state = stored.startMix;
  ref.read(blenderTargetPressureProvider.notifier).state =
      stored.targetPressureBar;
  ref.read(blenderTargetMixProvider.notifier).state = stored.targetMix;
  ref.read(blenderTopupO2PercentProvider.notifier).state =
      stored.topupO2Percent;
  ref.read(blenderFillOrderProvider.notifier).state = stored.fillOrder;
  ref.read(blenderFlushFeeEnabledProvider.notifier).state =
      stored.flushFeeEnabled;
  ref.read(blenderFlushFeeModeProvider.notifier).state = stored.flushFeeMode;
  ref.read(blenderFlushFeeGasesProvider.notifier).state = stored.flushFeeGases;
  if (stored.billedDate != null) {
    ref.read(blenderBilledDateProvider.notifier).state = stored.billedDate!;
  }
  ref.read(blenderArchivedInvoicesProvider.notifier).state =
      stored.archivedInvoices;
  // The input fields hold their own text, seeded once in initState. Without
  // this the cylinder volume and price boxes keep showing defaults over
  // freshly loaded preferences, and the next edit saves those defaults back
  // over what was stored (PR #1215 review).
  ref.read(blenderResetEpochProvider.notifier).state++;
});

const _log = LoggerService('GasBlenderPreferences');

/// Persist everything the blender remembers. Called after a settled edit, not
/// per keystroke, so typing a price is one database write rather than one per
/// character.
///
/// A failed write is logged rather than propagated. The repository rethrows so
/// the failure is never invisible, but a blender preference is not worth
/// interrupting a fill procedure over, and the value the diver just chose is
/// already live in the provider either way.
Future<void> saveBlenderPreferences(WidgetRef ref) async {
  try {
    await ref
        .read(appSettingsRepositoryProvider)
        .setBlenderPreferences(
          BlenderPreferences(
            templates: ref.read(blenderTemplatesProvider),
            gasPrices: ref.read(blenderGasPricesProvider),
            fillTempC: ref.read(blenderFillTempProvider),
            settledTempC: ref.read(blenderSettledTempProvider),
            cylinderWaterLiters: ref.read(blenderCylinderLitersProvider),
            model: ref.read(blenderGasModelProvider),
            billedFills: ref.read(blenderBilledFillsProvider),
            billedTo: ref.read(blenderBilledToProvider),
            startPressureBar: ref.read(blenderStartPressureProvider),
            startMix: ref.read(blenderStartMixProvider),
            targetPressureBar: ref.read(blenderTargetPressureProvider),
            targetMix: ref.read(blenderTargetMixProvider),
            topupO2Percent: ref.read(blenderTopupO2PercentProvider),
            fillOrder: ref.read(blenderFillOrderProvider),
            flushFeeEnabled: ref.read(blenderFlushFeeEnabledProvider),
            flushFeeMode: ref.read(blenderFlushFeeModeProvider),
            flushFeeGases: ref.read(blenderFlushFeeGasesProvider),
            billedDate: ref.read(blenderBilledDateProvider),
            archivedInvoices: ref.read(blenderArchivedInvoicesProvider),
          ),
        );
  } catch (e, stackTrace) {
    _log.error(
      'Failed to save blender preferences',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

/// Reset the gas blender inputs to defaults and re-seed its input fields.
///
/// Deliberately duplicated against [resetGasBlenderIn] rather than routed
/// through a shared generic callback: `WidgetRef` and `ProviderContainer` are
/// unrelated types that merely happen to share a `read` shape, and the generic
/// signature that unifies them is harder to read than twelve assignments.
void resetGasBlender(WidgetRef ref) {
  ref.read(blenderStartPressureProvider.notifier).state = 0.0;
  ref.read(blenderStartMixProvider.notifier).state = const GasMix(o2: 21);
  ref.read(blenderTargetPressureProvider.notifier).state = 200.0;
  ref.read(blenderTargetMixProvider.notifier).state = const GasMix(o2: 32);
  ref.read(blenderTopupO2PercentProvider.notifier).state = 21.0;
  ref.read(blenderFillOrderProvider.notifier).state = kDefaultBlenderFillOrder;
  ref.read(blenderFillTempProvider.notifier).state = kReferenceTempC;
  ref.read(blenderSettledTempProvider.notifier).state = kReferenceTempC;
  ref.read(blenderGasModelProvider.notifier).state = BlendGasModel.zFactor;
  ref.read(blenderResetEpochProvider.notifier).state++;
}

/// Test-facing form of [resetGasBlender].
void resetGasBlenderIn(ProviderContainer container) {
  container.read(blenderStartPressureProvider.notifier).state = 0.0;
  container.read(blenderStartMixProvider.notifier).state = const GasMix(o2: 21);
  container.read(blenderTargetPressureProvider.notifier).state = 200.0;
  container.read(blenderTargetMixProvider.notifier).state = const GasMix(
    o2: 32,
  );
  container.read(blenderTopupO2PercentProvider.notifier).state = 21.0;
  container.read(blenderFillOrderProvider.notifier).state =
      kDefaultBlenderFillOrder;
  container.read(blenderFillTempProvider.notifier).state = kReferenceTempC;
  container.read(blenderSettledTempProvider.notifier).state = kReferenceTempC;
  container.read(blenderGasModelProvider.notifier).state =
      BlendGasModel.zFactor;
  container.read(blenderResetEpochProvider.notifier).state++;
}
