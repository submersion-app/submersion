import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Lowest and highest default start pressure, in bar.
const double _minBar = 1;
const double _maxBar = 400;

/// The start pressure filled in on a new tank in the dive editor, and on an
/// imported tank that has none when the default tank is applied to imports
/// (issue #3091). Shown and edited in the diver's pressure unit; stored in
/// bar as a decimal, so 3000 psi reads back as 3000 psi.
class DefaultStartPressureTile extends ConsumerWidget {
  const DefaultStartPressureTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return ListTile(
      title: Text(context.l10n.tankPresets_defaultStartPressure),
      subtitle: Text(context.l10n.tankPresets_defaultStartPressure_subtitle),
      trailing: Text(
        units.formatPressure(settings.defaultStartPressure),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () async {
        final bar = await showDialog<double>(
          context: context,
          builder: (_) => _DefaultStartPressureDialog(units: units),
        );
        // A tolerance rather than ==: the value round-trips through the
        // diver's unit, so an unedited psi value can differ in the last bits.
        if (bar == null || (bar - settings.defaultStartPressure).abs() < 1e-6) {
          return;
        }
        if (!context.mounted) return;
        await ref.read(settingsProvider.notifier).setDefaultStartPressure(bar);
      },
    );
  }
}

/// Pops the entered pressure in bar, or null on cancel. Blank,
/// unreadable and out-of-range input keep the dialog open with the field's
/// error rather than closing with nothing saved (#1900).
class _DefaultStartPressureDialog extends StatefulWidget {
  const _DefaultStartPressureDialog({required this.units});

  final UnitFormatter units;

  @override
  State<_DefaultStartPressureDialog> createState() =>
      _DefaultStartPressureDialogState();
}

class _DefaultStartPressureDialogState
    extends State<_DefaultStartPressureDialog> {
  /// The stored value in the diver's unit, to one decimal, so 206.8428 bar
  /// opens as 3000 psi and a bar value keeps a typed half.
  late final TextEditingController _controller = TextEditingController(
    text: formatDecimalForInput(
      (widget.units.convertPressure(
                    widget.units.settings.defaultStartPressure,
                  ) *
                  10)
              .roundToDouble() /
          10,
    ),
  );
  final _formKey = GlobalKey<FormState>();

  /// The range's ends in the diver's unit, rounded the way the error
  /// message shows them ("15 psi" to "5802 psi"), so the dialog accepts
  /// exactly what the message promises.
  late final double _min = _shown(_minBar);
  late final double _max = _shown(_maxBar);

  double _shown(double bar) =>
      widget.units.convertPressure(bar).roundToDouble();

  /// The entered value in bar, or null when it is outside the range. The
  /// range is checked on the value as typed, so 0.5 bar is refused. The
  /// clamp only absorbs the display rounding at the ends (5802 psi is
  /// 400.03 bar).
  double? _toBar(double value) {
    if (value < _min || value > _max) return null;
    return widget.units.pressureToBar(value).clamp(_minBar, _maxBar);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final read = readNumber(_controller.text, allowNegative: false);
    if (read case NumberValue(:final value)) {
      Navigator.of(context).pop(_toBar(value));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = widget.units;
    return AlertDialog(
      title: Text(context.l10n.tankPresets_defaultStartPressure),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: numberInputFormatters(),
          validator: numberValidator(
            context,
            required: true,
            allowNegative: false,
            check: (value) => _toBar(value) == null
                ? context.l10n.tankPresets_defaultStartPressure_range(
                    units.formatPressure(_maxBar),
                    units.formatPressure(_minBar),
                  )
                : null,
          ),
          decoration: InputDecoration(suffixText: units.pressureSymbol),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(context.l10n.common_action_save),
        ),
      ],
    );
  }
}
