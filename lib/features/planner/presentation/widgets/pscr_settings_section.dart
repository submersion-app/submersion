import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/scr_calculator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/loop_flow_summary.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// pSCR ratio control for a passive semi-closed rebreather plan. The ratio is a
/// global equipment preference (Subsurface `pscr_ratio`): larger values add
/// more fresh gas and shrink the inspired-O2 drop.
///
/// Below it, the plan's own VO2 (issue #4660; an empty box follows the
/// diver's Settings) and the loop ppO2 drop the plan breathes with it.
class PscrSettingsSection extends ConsumerStatefulWidget {
  const PscrSettingsSection({super.key});

  @override
  ConsumerState<PscrSettingsSection> createState() =>
      _PscrSettingsSectionState();
}

class _PscrSettingsSectionState extends ConsumerState<PscrSettingsSection> {
  static const _debounceDelay = Duration(milliseconds: 300);

  late final TextEditingController _ratioController;
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  double? _pending;

  @override
  void initState() {
    super.initState();
    _ratioController = TextEditingController(
      text: _format(ref.read(pscrRatioProvider)),
    );
    // On blur, persist any pending edit immediately, then re-sync to the
    // authoritative (clamped) value.
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _flush();
        _syncFromProvider(ref.read(pscrRatioProvider));
      }
    });
  }

  @override
  void dispose() {
    _flush();
    _debounce?.cancel();
    _ratioController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Paired with [readNumber] in [_onChanged]: seeding with a dot while
  /// parsing in the diver's locale would misread the value (#1091).
  String _format(double ratio) => formatDecimalForInput(ratio.roundToDouble());

  /// Mirror [ratio] into the field unless the user is actively editing it, so
  /// external/async changes never clobber in-progress input.
  void _syncFromProvider(double ratio) {
    if (_focusNode.hasFocus) return;
    final text = _format(ratio);
    if (_ratioController.text != text) _ratioController.text = text;
  }

  void _onChanged(NumberRead read) {
    final parsed = switch (read) {
      NumberValue(:final value) => value,
      // The field shows why for unreadable text.
      NumberBlank() || NumberInvalid() => null,
    };
    if (parsed == null || parsed <= 0) {
      // Invalid/empty input: drop any pending valid value and cancel the
      // debounce so an earlier edit can't flush after the user has cleared or
      // invalidated the field. The field re-syncs to the saved value on blur.
      _debounce?.cancel();
      _pending = null;
      return;
    }
    _pending = parsed;
    // Debounce persistence: a burst of keystrokes collapses to a single,
    // ordered save of the final value rather than overlapping writes.
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, _flush);
  }

  void _flush() {
    _debounce?.cancel();
    final value = _pending;
    if (value == null) return;
    _pending = null;
    ref.read(settingsProvider.notifier).setPscrRatio(value);
  }

  @override
  Widget build(BuildContext context) {
    // pscrRatio loads asynchronously with the diver's settings and can
    // change elsewhere (another device, through sync); keep the field in
    // sync when the diver is not editing it.
    ref.listen<double>(pscrRatioProvider, (_, next) => _syncFromProvider(next));

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: NumberField(
                  controller: _ratioController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    labelText: context.l10n.plannerCanvas_pscr_ratio,
                    helperText: context.l10n.plannerCanvas_pscr_ratio_hint,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _PscrVo2Row(),
        ],
      ),
    );
  }
}

/// The plan's own pSCR VO2 in the diver's volume unit, and the loop ppO2 drop
/// it gives at the plan's bottom SAC and the diver's pSCR ratio (issue
/// #4660).
class _PscrVo2Row extends ConsumerWidget {
  const _PscrVo2Row();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(divePlanNotifierProvider);
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final units = ref.watch(unitFormatterProvider);
    // The diver's default for the hint; the drop is what the engine breathes
    // on the plan's resolved VO2, bottom SAC and ratio.
    final diver = ref.watch(planEngineConfigProvider);
    final defaultVo2 = diver.pscrVo2Lpm;
    final plan = planForEngine(state);
    final loop = breathingFor(
      plan,
      loopSupplyGas(plan),
      0,
      config: diver.resolvedFor(plan),
    );
    final drop = loop is PassiveScr ? loop.o2DropBar : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlanNumberField(
          label: context.l10n.plannerCanvas_pscr_vo2,
          value: state.pscrVo2 == null
              ? null
              : units.convertRmv(state.pscrVo2!),
          hintValue: units.convertRmv(defaultVo2),
          suffixText: units.rmvSymbol,
          decimals: units.loopFlowDecimals,
          min: units.convertRmv(ScrCalculator.minLoopFlowLpm),
          onChanged: (v) => notifier.updateLoopFlow(
            pscrVo2: v == null ? null : units.volumeToLiters(v),
            clearPscrVo2: v == null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.plannerCanvas_pscr_dropSummary(
            formatFixedForDisplay(drop, 2),
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
