import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// How long the diver breathed a cylinder at the surface after the computer
/// stopped logging, in minutes (issue #2930): oxygen on the boat after a deco
/// dive. The logged end pressure includes that gas, so SAC counts this time at
/// the surface. Reports null for a blank or zero field.
class TankSurfaceBreathingField extends StatefulWidget {
  const TankSurfaceBreathingField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Duration? value;
  final ValueChanged<Duration?> onChanged;

  @override
  State<TankSurfaceBreathingField> createState() =>
      _TankSurfaceBreathingFieldState();
}

class _TankSurfaceBreathingFieldState extends State<TankSurfaceBreathingField> {
  late final TextEditingController _controller = TextEditingController(
    text: _textOf(widget.value),
  );

  /// The last value this field reported, so a host echoing it back does not
  /// rewrite what the diver is typing ("1." would become "1").
  Duration? _reported;

  static String _textOf(Duration? value) =>
      value == null ? '' : formatDecimalForInput(value.inSeconds / 60);

  @override
  void initState() {
    super.initState();
    _reported = widget.value;
  }

  @override
  void didUpdateWidget(TankSurfaceBreathingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _reported) {
      _reported = widget.value;
      _controller.text = _textOf(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _report(Duration? value) {
    _reported = value;
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return NumberField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: l10n.diveLog_tank_label_surfaceBreathing,
        suffixText: l10n.diveLog_tank_surfaceBreathing_unit,
        helperText: l10n.diveLog_tank_surfaceBreathing_helper,
        helperMaxLines: 3,
        isDense: true,
      ),
      onChanged: (read) => switch (read) {
        NumberBlank() => _report(null),
        NumberValue(:final value) => _report(
          value > 0 ? Duration(seconds: (value * 60).round()) : null,
        ),
        // Keep the last readable value while the diver is mid-edit.
        NumberInvalid() => null,
      },
    );
  }
}
