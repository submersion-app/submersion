import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/deco/deco_ppo2_limits.dart';
import 'package:submersion/core/deco/max_operating_depth.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_choice_wrap.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_hypercapnia_control.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_ppo2_bands_control.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Subsurface-style "Gas options" for the Setup accordion's gas tab: Deco
/// SAC, SAC factor, problem solving time, bottom/deco ppO2 ceilings, best-mix
/// END, and the O2-narcotic switch - all per-plan, sitting alongside the
/// existing Bottom SAC and reserve controls in [PlanGasSection].
///
/// Each ppO2/O2-narcotic field is a nullable override of the app-wide
/// setting: an empty field (or, for the switch, no explicit choice) falls
/// back to the diver's global default, shown as the field's placeholder.
class PlanGasOptionsSection extends ConsumerWidget {
  const PlanGasOptionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(divePlanNotifierProvider);
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final globalPpO2Working = ref.watch(ppO2MaxWorkingProvider);
    final globalPpO2Deco = ref.watch(ppO2MaxDecoProvider);
    // Typed so `??` does not infer the watch as nullable.
    final double bottomRmv =
        state.sacRate ?? ref.watch(plannerSacBottomProvider);
    // While a Settings layer is off its stored values are not in force, so
    // this plan's Custom starts from the flat deco ppO2 the plan uses now
    // instead, rounded down onto the grid, so choosing Custom never raises
    // the ceiling by itself.
    final double planFlatPpO2 = state.ppO2Deco ?? globalPpO2Deco;
    final bandsInSettings = ref.watch(ppO2DecoBandsEnabledProvider);
    final maxO2DepthInSettings = ref.watch(maxO2DepthEnabledProvider);
    double defaultBand(double settingsBand) => bandsInSettings
        ? settingsBand
        : SettingsNotifier.ppO2DecoBandFloorOnGrid(planFlatPpO2);
    // The stressed rate the bailout falls back to, resolved the same way as
    // PlanEngineConfig.sacStressedFor.
    final double stressedRmv =
        state.sacStressed ??
        bottomRmv * ref.watch(plannerSacStressedFactorProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          context.l10n.divePlanner_gasOptions_title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_sacDeco,
          value: state.sacDeco != null
              ? units.convertRmv(state.sacDeco!)
              : null,
          hintValue: units.convertRmv(ref.watch(plannerSacDecoProvider)),
          suffixText: units.rmvSymbol,
          // Same precision as Bottom RMV: 2 decimals for cuft/min (#1823).
          decimals: units.rmvDecimals,
          onChanged: (value) => notifier.updateGasOptions(
            sacDeco: value != null ? units.volumeToLiters(value) : null,
            clearSacDeco: value == null,
          ),
        ),
        PlanNumberField(
          // An absolute rate, matching what the plan stores (sacStressed):
          // a typed factor stored as an absolute value would drift from
          // what the diver typed as soon as bottom RMV changed. Unset, it
          // follows bottom RMV times the diver's Settings stressed factor,
          // which the hint shows resolved (issue #3552).
          label: context.l10n.divePlanner_gasOptions_sacStressed,
          value: state.sacStressed != null
              ? units.convertRmv(state.sacStressed!)
              : null,
          hintValue: units.convertRmv(
            bottomRmv * ref.watch(plannerSacStressedFactorProvider),
          ),
          suffixText: units.rmvSymbol,
          decimals: units.rmvDecimals,
          onChanged: (value) => notifier.updateGasOptions(
            sacStressed: value != null ? units.volumeToLiters(value) : null,
            clearSacStressed: value == null,
          ),
        ),
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_sacFactor,
          value: state.sacFactor,
          hintValue: ref.watch(plannerBuddyFactorProvider),
          suffixText: '×',
          decimals: 1,
          onChanged: (value) => notifier.updateGasOptions(
            sacFactor: value,
            clearSacFactor: value == null,
          ),
        ),
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_problemSolvingMinutes,
          value: state.problemSolvingMinutes?.toDouble(),
          hintValue: ref.watch(plannerProblemSolvingMinutesProvider).toDouble(),
          suffixText: context.l10n.divePlanner_label_minutesUnit,
          isInteger: true,
          onChanged: (value) => notifier.updateGasOptions(
            problemSolvingMinutes: value?.round(),
            clearProblemSolvingMinutes: value == null,
          ),
        ),
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_gasSwitchStopSeconds,
          value: state.gasSwitchStopSeconds != null
              ? (state.gasSwitchStopSeconds! / 60).roundToDouble()
              : null,
          hintValue: (ref.watch(plannerGasSwitchStopSecondsProvider) / 60)
              .roundToDouble(),
          suffixText: context.l10n.divePlanner_label_minutesUnit,
          isInteger: true,
          onChanged: (value) => notifier.updateGasOptions(
            gasSwitchStopSeconds: value != null ? (value * 60).round() : null,
            clearGasSwitchStopSeconds: value == null,
          ),
        ),
        // Shown above Grund-ppO2/Deko-ppO2 (issue #3580 follow-up): the band
        // control is the first thing that decides whether the flat Deko-ppO2
        // field below even applies, so it reads as the governing choice,
        // with Grund-ppO2 and (when bands aren't in charge) Deko-ppO2 as the
        // plain fallback values beneath it.
        PlanPpO2BandsControl(
          band1: state.ppO2DecoBand1,
          band2: state.ppO2DecoBand2,
          band3: state.ppO2DecoBand3,
          explicitlyOff: state.ppO2DecoBandsExplicitlyOff,
          defaultBand1: defaultBand(ref.watch(ppO2DecoBand1Provider)),
          defaultBand2: defaultBand(ref.watch(ppO2DecoBand2Provider)),
          defaultBand3: defaultBand(ref.watch(ppO2DecoBand3Provider)),
          bandsEnabledInSettings: bandsInSettings,
          onBand1Changed: (value) =>
              notifier.updateGasOptions(ppO2DecoBand1: value),
          onBand2Changed: (value) =>
              notifier.updateGasOptions(ppO2DecoBand2: value),
          onBand3Changed: (value) =>
              notifier.updateGasOptions(ppO2DecoBand3: value),
          onOff: (off) =>
              notifier.updateGasOptions(ppO2DecoBandsExplicitlyOff: off),
          onDefault: () => notifier.updateGasOptions(
            clearPpO2DecoBand1: true,
            clearPpO2DecoBand2: true,
            clearPpO2DecoBand3: true,
            ppO2DecoBandsExplicitlyOff: false,
          ),
        ),
        const SizedBox(height: 8),
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_ppO2Bottom,
          value: state.ppO2Bottom,
          hintValue: globalPpO2Working,
          suffixText: 'bar',
          decimals: 2,
          onChanged: (value) => notifier.updateGasOptions(
            ppO2Bottom: value,
            clearPpO2Bottom: value == null,
          ),
        ),
        // Hidden while per-band deco ppO2 limits actually govern this plan's
        // deco gases (issue #3580 follow-up): the flat value below is then
        // replaced everywhere by the band it falls into, so showing it next
        // to the bands control reads as if it still mattered. Shown again
        // once this plan's own choice is "Off" - or neither the diver's
        // Settings nor this plan's own Custom values turned band mode on -
        // and the flat value is back in charge. Mirrors the same
        // resolveDecoLayerEnabled formula PlanEngineConfig.resolvedFor
        // actually computes band mode with, so this field hides exactly
        // when it stops mattering, not just when the Settings toggle does.
        if (!resolveDecoLayerEnabled(
          settingsEnabled: bandsInSettings,
          explicitlyOff: state.ppO2DecoBandsExplicitlyOff,
          hasCustomValue: hasCustomDecoBands(
            state.ppO2DecoBand1,
            state.ppO2DecoBand2,
            state.ppO2DecoBand3,
          ),
        ))
          PlanNumberField(
            label: context.l10n.divePlanner_gasOptions_ppO2Deco,
            value: state.ppO2Deco,
            hintValue: globalPpO2Deco,
            suffixText: 'bar',
            decimals: 2,
            onChanged: (value) => notifier.updateGasOptions(
              ppO2Deco: value,
              clearPpO2Deco: value == null,
            ),
          ),
        const SizedBox(height: 8),
        PlanMaxO2DepthControl(
          maxO2DepthMeters: state.maxO2DepthMeters,
          explicitlyOff: state.maxO2DepthExplicitlyOff,
          defaultMaxO2DepthMeters: maxO2DepthInSettings
              ? ref.watch(maxO2DepthMetersProvider)
              : SettingsNotifier.maxO2DepthFloorOnGrid(
                  maxOperatingDepthMeters(1.0, maxPpO2: planFlatPpO2),
                ),
          enabledInSettings: maxO2DepthInSettings,
          units: units,
          onChanged: (value) =>
              notifier.updateGasOptions(maxO2DepthMeters: value),
          onOff: (off) =>
              notifier.updateGasOptions(maxO2DepthExplicitlyOff: off),
          onDefault: () => notifier.updateGasOptions(
            clearMaxO2DepthMeters: true,
            maxO2DepthExplicitlyOff: false,
          ),
        ),
        // Hypercapnia-bailout phase (issue #3743): an elevated breathing
        // rate for a configurable duration at the start of an OC bailout -
        // its own layer over the stressed-SAC field above, same
        // Default/Off/Custom shape as the ppO2-band controls. Only a loop
        // plan has an OC bailout, so an OC plan never shows it.
        if (state.mode != PlanMode.oc) ...[
          const SizedBox(height: 8),
          PlanHypercapniaControl(
            amv: state.hypercapniaAmv,
            minutes: state.hypercapniaMinutes,
            explicitlyOff: state.hypercapniaExplicitlyOff,
            // Never below the stressed rate, as BailoutSolver charges it.
            defaultAmv: math.max(
              bottomRmv * ref.watch(plannerHypercapniaFactorProvider),
              stressedRmv,
            ),
            defaultMinutes: ref.watch(plannerHypercapniaMinutesProvider),
            enabledInSettings: ref.watch(plannerHypercapniaEnabledProvider),
            units: units,
            onAmvChanged: (value) =>
                notifier.updateGasOptions(hypercapniaAmv: value),
            onMinutesChanged: (value) =>
                notifier.updateGasOptions(hypercapniaMinutes: value),
            onOff: (off) =>
                notifier.updateGasOptions(hypercapniaExplicitlyOff: off),
            onDefault: () => notifier.updateGasOptions(
              clearHypercapniaAmv: true,
              clearHypercapniaMinutes: true,
              hypercapniaExplicitlyOff: false,
            ),
          ),
        ],
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_bestMixEnd,
          value: state.bestMixEndMeters != null
              ? units.convertDepth(state.bestMixEndMeters!)
              : null,
          hintValue: units.convertDepth(
            ref.watch(plannerBestMixEndMetersProvider),
          ),
          suffixText: units.depthSymbol,
          decimals: 0,
          onChanged: (value) => notifier.updateGasOptions(
            bestMixEndMeters: value != null ? units.depthToMeters(value) : null,
            clearBestMixEndMeters: value == null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.divePlanner_gasOptions_o2Narcotic),
              const SizedBox(height: 6),
              // A Wrap of chips, not a SegmentedButton: see
              // PlanLastStopSelector's matching fix for the full reasoning.
              // Unlike a SegmentedButton, a Wrap can show the Default chip's
              // resolved value without risking it pushing another chip out
              // of view - a chip that does not fit just starts the next
              // line.
              PlanChoiceWrap<bool?>(
                options: [
                  (
                    null,
                    context.l10n.divePlanner_label_defaultWithValue(
                      settings.o2Narcotic
                          ? context.l10n.divePlanner_label_on
                          : context.l10n.divePlanner_label_off,
                    ),
                  ),
                  (true, context.l10n.divePlanner_label_on),
                  (false, context.l10n.divePlanner_label_off),
                ],
                selected: state.o2Narcotic,
                onChanged: (value) => notifier.updateGasOptions(
                  o2Narcotic: value,
                  clearO2Narcotic: value == null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
