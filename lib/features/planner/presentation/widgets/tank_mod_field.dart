import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/services/tank_mod.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// A cylinder's MOD, with the default for its role or a depth set by hand
/// (issue #3567).
///
/// Shows the default until the diver types a depth, which becomes the
/// override reported through [onChanged]; clearing the field or Reset
/// reports null, back to the default. Below it, [TankModDetails] says what
/// the value means. A default is never reported, so it keeps following the
/// mix and the limits.
///
/// Used by the saved-cylinder card and the planner's tank dialog, so the two
/// cannot disagree about what a MOD means.
class TankModField extends StatefulWidget {
  const TankModField({
    super.key,
    required this.gas,
    required this.role,
    required this.overrideMeters,
    required this.bottomPpO2,
    required this.decoPpO2,
    required this.diluentPpO2,
    required this.units,
    required this.onChanged,
    this.showDetails = true,
  });

  final GasMix gas;

  /// The cylinder's role, resolved: it decides which limit the default uses.
  final TankRole role;

  /// The MOD set by hand, in metres, or null for the default.
  final double? overrideMeters;
  final double bottomPpO2;
  final double decoPpO2;

  /// The CCR "Dil MOD" limit a diluent cylinder's default follows, from the
  /// diver's "ppO2 limits CCR" Settings. Unused for every other role.
  final double diluentPpO2;
  final UnitFormatter units;

  /// The new override in metres, or null when it was cleared.
  final ValueChanged<double?> onChanged;

  /// Whether [TankModDetails] is drawn under the field. A host that sets the
  /// field in a narrow column turns this off and places the details itself,
  /// across the full width.
  final bool showDetails;

  static const fieldKey = ValueKey('tank-mod-field');
  static const resetKey = ValueKey('tank-mod-reset');

  @override
  State<TankModField> createState() => _TankModFieldState();
}

class _TankModFieldState extends State<TankModField> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _expectedText());
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant TankModField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // While the diver is typing the field keeps what they typed, so a
    // half-entered or unreadable value can say why; otherwise it follows the
    // value: the override, or a default that moves with the mix. The one
    // exception is a Reset made outside the field while it still holds a
    // typed depth: the default it went back to must show at once.
    final resetElsewhere =
        widget.overrideMeters == null &&
        switch (readNumber(_controller.text, allowNegative: false)) {
          NumberValue(:final value) => value >= _minMod,
          NumberBlank() || NumberInvalid() => false,
        };
    if (!_focus.hasFocus || resetElsewhere) {
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
    if (!_focus.hasFocus) setState(_syncText);
  }

  void _syncText() {
    final expected = _expectedText();
    if (_controller.text != expected) _controller.text = expected;
  }

  /// The override as typed, to a tenth of the diver's unit; otherwise the
  /// default, rounded down (see [shownDefaultMod]).
  String _expectedText() {
    final override = widget.overrideMeters;
    if (override != null) {
      return formatRoundedForInput(widget.units.convertDepth(override), 1);
    }
    return '${shownDefaultMod(widget.gas, widget.role, widget.bottomPpO2, widget.decoPpO2, widget.diluentPpO2, widget.units)}';
  }

  /// The shallowest MOD the field takes, in the diver's depth unit: a gas
  /// never breathed below the surface has no MOD worth planning on.
  static const double _minMod = 1;

  void _onText(NumberRead read) {
    switch (read) {
      case NumberBlank():
        widget.onChanged(null);
      case NumberValue(:final value) when value >= _minMod:
        widget.onChanged(widget.units.depthToMeters(value));
      case NumberValue() || NumberInvalid():
        // Nothing to store; the field says why, and an enclosing Form
        // refuses to save until it is fixed.
        break;
    }
  }

  void _reset() {
    _focus.unfocus();
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final override = widget.overrideMeters;
    final exceeds = switch (override) {
      final meters? => modOverrideCheckFor(
        widget.role,
        widget.gas,
        meters,
        bottomPpO2: widget.bottomPpO2,
        decoPpO2: widget.decoPpO2,
        diluentPpO2: widget.diluentPpO2,
      ).exceedsLimit,
      null => false,
    };

    final field = NumberField(
      key: TankModField.fieldKey,
      controller: _controller,
      focusNode: _focus,
      check: (value) => value < _minMod ? l10n.numberInput_atLeastOne : null,
      // A default is shown muted, so it reads as "not set by you".
      style: override == null
          ? TextStyle(color: scheme.onSurfaceVariant)
          : null,
      decoration: InputDecoration(
        labelText: l10n.tankMod_label,
        suffixText: widget.units.depthSymbol,
        isDense: true,
        suffixIcon: exceeds
            ? Icon(Icons.warning_amber_rounded, color: scheme.error)
            : null,
        enabledBorder: exceeds
            ? UnderlineInputBorder(borderSide: BorderSide(color: scheme.error))
            : null,
      ),
      onChanged: _onText,
    );
    if (!widget.showDetails) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        field,
        const SizedBox(height: 4),
        TankModDetails(
          gas: widget.gas,
          role: widget.role,
          overrideMeters: override,
          bottomPpO2: widget.bottomPpO2,
          decoPpO2: widget.decoPpO2,
          diluentPpO2: widget.diluentPpO2,
          units: widget.units,
          onReset: _reset,
        ),
      ],
    );
  }
}

/// What a cylinder's MOD means (issue #3567): the limit a default comes
/// from, or for a MOD set by hand, the default it replaces with a Reset, and
/// the ppO2 it reaches, in red when that is above the cylinder's limit.
///
/// Drawn by [TankModField] under itself, or by a host on a line of its own.
class TankModDetails extends StatelessWidget {
  const TankModDetails({
    super.key,
    required this.gas,
    required this.role,
    required this.overrideMeters,
    required this.bottomPpO2,
    required this.decoPpO2,
    required this.diluentPpO2,
    required this.units,
    required this.onReset,
  });

  final GasMix gas;
  final TankRole role;
  final double? overrideMeters;
  final double bottomPpO2;
  final double decoPpO2;

  /// The CCR "Dil MOD" limit a diluent cylinder's default follows, from the
  /// diver's "ppO2 limits CCR" Settings. Unused for every other role.
  final double diluentPpO2;
  final UnitFormatter units;

  /// Clears the MOD set by hand.
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final override = overrideMeters;
    final limitName = switch (modLimitClassFor(role, gas)) {
      ModLimitClass.deco => l10n.tankMod_limitDeco,
      ModLimitClass.bottom => l10n.tankMod_limitBottom,
      ModLimitClass.diluent => l10n.tankMod_limitDiluent,
    };
    final small = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    if (override == null) {
      final limit = modPpO2For(
        role,
        gas,
        bottomPpO2: bottomPpO2,
        decoPpO2: decoPpO2,
        diluentPpO2: diluentPpO2,
      );
      return Text(
        l10n.tankMod_default(formatFixedForDisplay(limit, 1), limitName),
        style: small,
      );
    }

    final check = modOverrideCheckFor(
      role,
      gas,
      override,
      bottomPpO2: bottomPpO2,
      decoPpO2: decoPpO2,
      diluentPpO2: diluentPpO2,
    );
    final defaultMeters = defaultModMeters(
      role,
      gas,
      bottomPpO2: bottomPpO2,
      decoPpO2: decoPpO2,
      diluentPpO2: diluentPpO2,
    );
    final depth = units.formatDepth(override, decimals: 0);
    final ppO2 = formatFixedForDisplay(check.ppO2, 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.tankMod_overridden(
                  units.formatDepthFloor(defaultMeters, decimals: 0),
                ),
                style: small,
              ),
            ),
            TextButton(
              key: TankModField.resetKey,
              onPressed: onReset,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(l10n.tankMod_reset),
            ),
          ],
        ),
        Text(
          check.exceedsLimit
              ? l10n.tankMod_exceeds(
                  ppO2,
                  depth,
                  limitName,
                  formatFixedForDisplay(check.limitPpO2, 1),
                )
              : l10n.tankMod_ppO2At(ppO2, depth),
          style: check.exceedsLimit
              ? theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w500,
                )
              : small,
        ),
      ],
    );
  }
}

/// The default MOD as the field shows it: in the diver's depth unit, rounded
/// DOWN to a whole unit so the MOD shown is never deeper than the real one.
/// The epsilon keeps float noise (21.9999999) from dropping a whole unit.
int shownDefaultMod(
  GasMix gas,
  TankRole role,
  double bottomPpO2,
  double decoPpO2,
  double diluentPpO2,
  UnitFormatter units,
) {
  final meters = defaultModMeters(
    role,
    gas,
    bottomPpO2: bottomPpO2,
    decoPpO2: decoPpO2,
    diluentPpO2: diluentPpO2,
  );
  return (units.convertDepth(meters) + 1e-6).floor();
}
