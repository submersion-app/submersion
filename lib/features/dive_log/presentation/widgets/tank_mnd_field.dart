import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// A cylinder's MND (maximum narcotic depth), which works out its helium.
///
/// Shows [gas]'s MND in the diver's depth unit, to a whole unit. A depth the
/// diver types becomes a He percentage, to a whole percent, reported through
/// [onHeChanged]. Both follow the diver's END limit and O2-narcotic setting,
/// read from [units].
///
/// While the diver is typing the field keeps what they typed, so an
/// unreadable entry can say why and the rounded He does not rewrite a typed
/// depth; leaving it shows the MND the mix really has. A mix changed
/// elsewhere, such as by a gas chip, shows at once, focus or not.
///
/// The MND is a helper, never stored, so an unreadable entry shows an error
/// without making an enclosing Form refuse to save.
///
/// Used by the dive log's tank card and the saved-cylinder card (issue
/// #3660), so the two cannot work out a different He for the same MND.
class TankMndField extends StatefulWidget {
  const TankMndField({
    super.key,
    required this.gas,
    required this.units,
    required this.onHeChanged,
  });

  final GasMix gas;

  /// The diver's units, and through them the END limit and O2-narcotic
  /// setting.
  final UnitFormatter units;

  /// The He percentage, a whole number, for the MND the diver typed.
  final ValueChanged<double> onHeChanged;

  @override
  State<TankMndField> createState() => _TankMndFieldState();
}

class _TankMndFieldState extends State<TankMndField> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  /// The mix the last typed MND produced, or null when the field follows
  /// the mix.
  GasMix? _drivenMix;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _expectedText());
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant TankMndField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A mix that is not the one the typed MND produced was changed
    // elsewhere: a gas chip, a fill, the O2 or He field. It shows at once,
    // even with focus, which a touch tap elsewhere leaves on this field.
    final changedElsewhere =
        widget.gas != oldWidget.gas && widget.gas != _drivenMix;
    if (_drivenMix != null && widget.gas != _drivenMix) _drivenMix = null;
    if ((changedElsewhere || (!_focus.hasFocus && _drivenMix == null)) &&
        _controller.text != _expectedText()) {
      // After the frame: the field is a form field, and a controller change
      // now would mark the enclosing Form dirty in the middle of its build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncText();
      });
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Leaving the box always shows the mix's MND, including after an
    // unreadable entry.
    if (!_focus.hasFocus) {
      setState(() {
        _drivenMix = null;
        _syncText();
      });
    }
  }

  void _syncText() {
    final expected = _expectedText();
    if (_controller.text != expected) _controller.text = expected;
  }

  /// The mix's MND in the diver's depth unit, or blank when it has none.
  String _expectedText() {
    final settings = widget.units.settings;
    final mnd = widget.gas.mnd(
      endLimit: settings.endLimit,
      o2Narcotic: settings.o2Narcotic,
    );
    return mnd.isFinite
        ? formatDecimalForInput(widget.units.convertDepth(mnd).roundToDouble())
        : '';
  }

  void _onText(String text) {
    if (readNumber(text, allowNegative: false) case NumberValue(
      :final value,
    ) when value > 0) {
      final settings = widget.units.settings;
      final o2 = widget.gas.o2;
      final he = GasMix.heForMnd(
        widget.units.depthToMeters(value),
        o2,
        endLimit: settings.endLimit,
        o2Narcotic: settings.o2Narcotic,
      ).roundToDouble();
      // An MND no deeper than the END limit needs no helium. It is most
      // often the first key of a deeper one, and a He of 0 would make a
      // host that shows this field only for a mix with helium take it away
      // while the diver types, so it is not reported.
      if (he > 0) {
        _drivenMix = GasMix(o2: o2, he: he);
        widget.onHeChanged(he);
      } else {
        _drivenMix = null;
      }
    } else {
      // No MND to work the He out from; the field says why.
      _drivenMix = null;
    }
    // Rebuild for the error line, if any.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      controller: _controller,
      focusNode: _focus,
      decoration: InputDecoration(
        labelText: l10n.diveLog_tank_label_mnd,
        suffixText: widget.units.depthSymbol,
        isDense: true,
        helperText: l10n.diveLog_tank_mndHelper,
        // Shown, not validated: the MND is not saved, so it says why
        // without blocking the save (#1900 review).
        errorText: invalidNumberText(
          context,
          _controller.text,
          allowNegative: false,
        ),
        errorMaxLines: 3,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: numberInputFormatters(),
      onChanged: _onText,
    );
  }
}
