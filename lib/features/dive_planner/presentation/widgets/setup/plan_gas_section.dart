import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_gas_options_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';

/// Gas settings for the Setup accordion: Bottom RMV (with one-tap logged
/// average), reserve pressure, and the Subsurface-style Gas options
/// ([PlanGasOptionsSection]: Deco RMV, RMV factor, problem solving time,
/// bottom/deco ppO2, best-mix END, O2 narcotic).
///
/// The app calls the volume rate RMV (AMV in German) and reserves SAC for the
/// pressure rate, so these labels say RMV even though the state field and the
/// stored columns keep their historical `sac` names.
class PlanGasSection extends ConsumerWidget {
  const PlanGasSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(divePlanNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The plan keeps its RMV in L/min; the field shows it in the diver's
        // volume unit at rmvDecimals, so an imperial 0.55 cuft/min is not
        // re-seeded as "0.6" mid-entry (#1823).
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_sacBottom,
          value: planState.sacRate != null
              ? units.convertRmv(planState.sacRate!)
              : null,
          hintValue: units.convertRmv(ref.watch(plannerSacBottomProvider)),
          suffixText: units.rmvSymbol,
          decimals: units.rmvDecimals,
          semanticsLabel: context.l10n.divePlanner_semantics_sacRate(
            formatFixedForDisplay(
              units.convertRmv(
                planState.sacRate ?? ref.watch(plannerSacBottomProvider),
              ),
              units.rmvDecimals,
            ),
            units.volumeSymbol,
          ),
          onChanged: (value) {
            if (value == null) {
              ref.read(divePlanNotifierProvider.notifier).clearSacRate();
              return;
            }
            final liters = units.volumeToLiters(value);
            if (liters > 0) {
              ref.read(divePlanNotifierProvider.notifier).updateSacRate(liters);
            }
          },
        ),
        _LoggedRmvButton(
          currentRmv: planState.sacRate ?? ref.watch(plannerSacBottomProvider),
          units: units,
        ),
        const SizedBox(height: 12),
        _ReservePressureInput(
          reservePressure: planState.reservePressure,
          defaultPressureBar: ref.watch(plannerReservePressureProvider),
          maxPressureBar: planState.tanks
              .map((t) => t.startPressure ?? 0.0)
              .fold(0.0, (a, b) => a > b ? a : b),
          units: units,
          onChanged: (value) => ref
              .read(divePlanNotifierProvider.notifier)
              .updateReservePressure(value),
        ),
        const PlanGasOptionsSection(),
      ],
    );
  }
}

/// One-tap SAC auto-fill from the diver's logged average ("from your log").
/// Hidden when no logged average exists or it already matches the plan.
class _LoggedRmvButton extends ConsumerWidget {
  const _LoggedRmvButton({required this.currentRmv, required this.units});

  final double currentRmv;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedRmv = ref.watch(loggedAverageSacProvider).valueOrNull;
    if (loggedRmv == null || (loggedRmv - currentRmv).abs() < 0.5) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: const Icon(Icons.history, size: 18),
        label: Text(
          context.l10n.plannerCanvas_sac_useLogged(units.formatRmv(loggedRmv)),
        ),
        onPressed: () => ref
            .read(divePlanNotifierProvider.notifier)
            // Clamped in L/min, not in the diver's unit, so the plan gets the
            // same RMV whichever unit the diver reads.
            .updateSacRate(loggedRmv.clamp(8.0, 30.0)),
      ),
    );
  }
}

/// Reserve pressure input field with validation.
///
/// Null = use the diver's Settings default (issue #3552, follow-up to
/// v304-307) - the box is empty and shows the default as a hint, the same
/// pattern [PlanNumberField] uses, retrofitted onto this field's own
/// hand-rolled controller rather than switching to [PlanNumberField]
/// itself, which has no room for the tank-max validation this field needs.
class _ReservePressureInput extends StatefulWidget {
  final double? reservePressure;
  final double defaultPressureBar;
  final double maxPressureBar;
  final UnitFormatter units;
  final ValueChanged<double?> onChanged;

  const _ReservePressureInput({
    required this.reservePressure,
    required this.defaultPressureBar,
    required this.maxPressureBar,
    required this.units,
    required this.onChanged,
  });

  @override
  State<_ReservePressureInput> createState() => _ReservePressureInputState();
}

class _ReservePressureInputState extends State<_ReservePressureInput> {
  late TextEditingController _controller;
  String? _errorText;

  /// The seed and the parse must share one convention, so a whole-pressure
  /// seed is rendered in the diver's locale rather than with toStringAsFixed
  /// (#1091).
  String _seed(double bar) =>
      formatDecimalForInput(widget.units.convertPressure(bar).roundToDouble());

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.reservePressure != null
          ? _seed(widget.reservePressure!)
          : '',
    );
  }

  @override
  void didUpdateWidget(_ReservePressureInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reservePressure != widget.reservePressure) {
      final newText = widget.reservePressure != null
          ? _seed(widget.reservePressure!)
          : '';
      if (_controller.text != newText) {
        _controller.text = newText;
      }
    }
    // Re-validate against new max if tanks changed
    if (oldWidget.maxPressureBar != widget.maxPressureBar) {
      setState(() => _errorText = _getError(_controller.text));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The reserve in whole display units, or null when blank or unreadable.
  double? _reserve(String value) => switch (readNumber(value, integer: true)) {
    NumberValue(:final value) => value,
    NumberBlank() || NumberInvalid() => null,
  };

  String? _getError(String value) {
    if (value.isEmpty) return null;
    // A fraction or a typo is reported rather than read as a different
    // whole number, which a digits-only filter used to do (#1900 review).
    final unreadable = invalidNumberText(context, value, integer: true);
    if (unreadable != null) return unreadable;
    final parsed = _reserve(value);
    if (parsed == null) return null;
    final bar = widget.units.pressureToBar(parsed);
    if (bar <= 0) return context.l10n.divePlanner_error_reserveMustBePositive;
    if (widget.maxPressureBar > 0 &&
        parsed >
            widget.units
                .convertPressure(widget.maxPressureBar)
                .roundToDouble()) {
      return context.l10n.divePlanner_error_reserveExceedsTank;
    }
    return null;
  }

  void _validate(String value) {
    if (value.isEmpty) {
      setState(() => _errorText = null);
      widget.onChanged(null);
      return;
    }
    final error = _getError(value);
    setState(() => _errorText = error);
    if (error == null) {
      final parsed = _reserve(value);
      if (parsed != null) {
        widget.onChanged(widget.units.pressureToBar(parsed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(context.l10n.divePlanner_label_reserve)),
              const SizedBox(width: 8),
              SizedBox(
                width: PlanNumberField.fieldWidth,
                child: Semantics(
                  label: context.l10n.divePlanner_semantics_reservePressure(
                    widget.units.pressureSymbol,
                  ),
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      hintText: _seed(widget.defaultPressureBar),
                      hintStyle: TextStyle(color: theme.colorScheme.primary),
                      errorText: _errorText != null ? '' : null,
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: numberInputFormatters(),
                    onChanged: _validate,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: PlanNumberField.unitWidth,
                child: Text(widget.units.pressureSymbol),
              ),
            ],
          ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
