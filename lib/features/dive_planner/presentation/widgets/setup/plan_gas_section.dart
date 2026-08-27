import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Gas settings for the Setup accordion: RMV (with one-tap logged average)
/// and reserve pressure. Bottom/deco RMV split and RMV factor land here in
/// later phases (spec G25).
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
        Row(
          children: [
            Flexible(
              flex: 0,
              child: Text(context.l10n.divePlanner_label_sacRate),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                label: context.l10n.divePlanner_semantics_sacRate(
                  planState.sacRate.toStringAsFixed(0),
                  units.volumeSymbol,
                ),
                child: Slider(
                  value: planState.sacRate,
                  min: 8,
                  max: 30,
                  divisions: 22,
                  label:
                      '${planState.sacRate.toStringAsFixed(0)} ${units.volumeSymbol}/min',
                  onChanged: (value) => ref
                      .read(divePlanNotifierProvider.notifier)
                      .updateSacRate(value),
                ),
              ),
            ),
            SizedBox(
              width: 70,
              child: Text(
                '${planState.sacRate.toStringAsFixed(0)} ${units.volumeSymbol}/min',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        _LoggedRmvButton(currentRmv: planState.sacRate, units: units),
        const SizedBox(height: 12),
        _ReservePressureInput(
          reservePressure: planState.reservePressure,
          defaultPressureBar: settings.pressureUnit == PressureUnit.psi
              ? PressureUnit.psi.convert(500, PressureUnit.bar)
              : DivePlanState.kDefaultReservePressureBar,
          maxPressureBar: planState.tanks
              .map((t) => t.startPressure ?? 0.0)
              .fold(0.0, (a, b) => a > b ? a : b),
          units: units,
          compact: true,
          onChanged: (value) => ref
              .read(divePlanNotifierProvider.notifier)
              .updateReservePressure(value),
        ),
      ],
    );
  }
}

/// One-tap RMV auto-fill from the diver's logged average ("from your log").
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

    final display =
        '${units.convertVolume(loggedRmv).toStringAsFixed(1)} '
        '${units.volumeSymbol}/min';
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: const Icon(Icons.history, size: 18),
        label: Text(context.l10n.plannerCanvas_sac_useLogged(display)),
        onPressed: () => ref
            .read(divePlanNotifierProvider.notifier)
            .updateSacRate(loggedRmv.clamp(8.0, 30.0)),
      ),
    );
  }
}

/// Reserve pressure input field with validation.
class _ReservePressureInput extends StatefulWidget {
  final double reservePressure;
  final double defaultPressureBar;
  final double maxPressureBar;
  final UnitFormatter units;
  final bool compact;
  final ValueChanged<double> onChanged;

  const _ReservePressureInput({
    required this.reservePressure,
    required this.defaultPressureBar,
    required this.maxPressureBar,
    required this.units,
    this.compact = false,
    required this.onChanged,
  });

  @override
  State<_ReservePressureInput> createState() => _ReservePressureInputState();
}

class _ReservePressureInputState extends State<_ReservePressureInput> {
  late TextEditingController _controller;
  String? _messageText;
  bool _isError = false;

  /// The seed and the parse must share one convention, so a whole-pressure
  /// seed is rendered in the diver's locale rather than with toStringAsFixed
  /// (#1091).
  String _seed(double bar) =>
      formatDecimalForInput(widget.units.convertPressure(bar).roundToDouble());

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _seed(widget.reservePressure));
  }

  @override
  void didUpdateWidget(_ReservePressureInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reservePressure != widget.reservePressure) {
      final newText = _seed(widget.reservePressure);
      if (_controller.text != newText) {
        _controller.text = newText;
      }
    }
    // Re-validate against new max if tanks changed
    if (oldWidget.maxPressureBar != widget.maxPressureBar) {
      final error = _getError(_controller.text);
      setState(() {
        _messageText = error;
        _isError = error != null;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _getError(String value) {
    final parsed = parseUserDecimal(value);
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
      final defaultDisplay = _seed(widget.defaultPressureBar);
      setState(() {
        _messageText = context.l10n.divePlanner_info_reserveDefault(
          widget.units.pressureSymbol,
          defaultDisplay,
        );
        _isError = false;
      });
      widget.onChanged(widget.defaultPressureBar);
      return;
    }
    final error = _getError(value);
    setState(() {
      _messageText = error;
      _isError = error != null;
    });
    if (error == null) {
      final parsed = parseUserDecimal(value);
      if (parsed != null) {
        widget.onChanged(widget.units.pressureToBar(parsed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textField = SizedBox(
      width: 80,
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
            suffixText: widget.units.pressureSymbol,
            errorText: _isError ? '' : null,
            errorStyle: const TextStyle(height: 0, fontSize: 0),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _validate,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: widget.compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.compact) ...[
          Text(context.l10n.divePlanner_label_reserve),
          const SizedBox(height: 4),
          textField,
        ] else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(context.l10n.divePlanner_label_reserve)),
              const SizedBox(width: 8),
              textField,
            ],
          ),
        if (_messageText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _messageText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _isError
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
