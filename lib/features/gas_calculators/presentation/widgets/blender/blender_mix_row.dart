import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A row of pressure (optional) plus O2 plus He fields.
///
/// The unit lives in the label rather than in `suffixText`. A suffix costs
/// roughly 30 logical pixels inside the field, which on a phone is the
/// difference between showing "65.9" and clipping it. Below [_stackBelow] the
/// pressure field takes its own line instead of sharing one with two
/// percentages.
class BlenderMixRow extends StatelessWidget {
  const BlenderMixRow({
    super.key,
    this.leading,
    this.leadingWidth,
    this.pressureController,
    this.onPressure,
    required this.o2Controller,
    required this.heController,
    required this.onMix,
    required this.pressureSymbol,
    this.onSave,
    this.errorText,
    this.priceController,
    this.priceLabel,
    this.onPriceChanged,
  });

  static const double _stackBelow = 420;

  final String? leading;

  /// A shared width for [leading] across a set of rows, so the O2/He fields
  /// line up regardless of how long each row's gas name happens to be.
  /// Natural (text-sized) width when null.
  final double? leadingWidth;

  final TextEditingController? pressureController;
  final ValueChanged<String>? onPressure;
  final TextEditingController o2Controller;
  final TextEditingController heController;
  final VoidCallback onMix;
  final String pressureSymbol;

  /// Fired on blur/submit of any field in the row, not per keystroke -- the
  /// same debounce every other persisted blender field uses. Null when the
  /// row's values are not persisted.
  final VoidCallback? onSave;

  /// Shown under both the O2 and He fields when set, and under neither the
  /// pressure nor the price field. The two fractions are only ever invalid
  /// together (negative, or summing past 100%), so there is no single field to
  /// pin the message to -- but a pressure or a price has nothing to do with an
  /// invalid mix, and repeating the message under those fields would only
  /// suggest they need fixing too.
  final String? errorText;

  /// A price field for this row's gas, shown below the O2/He fields when set
  /// (Eric's PR #1359 review point 3: the price belongs next to the gas it
  /// prices, not in a separate card at the other end of the page).
  final TextEditingController? priceController;
  final String? priceLabel;
  final ValueChanged<String>? onPriceChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            pressureController != null && constraints.maxWidth < _stackBelow;
        final percentages = Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _o2Field(context)),
            const SizedBox(width: 8),
            Expanded(child: _heField(context)),
          ],
        );

        final Widget mixRow;
        if (stacked) {
          mixRow = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) _leadingLabel(context),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _pressureField(context),
                    const SizedBox(height: 8),
                    percentages,
                  ],
                ),
              ),
            ],
          );
        } else {
          mixRow = Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (leading != null) _leadingLabel(context),
              if (pressureController != null) ...[
                Expanded(flex: 4, child: _pressureField(context)),
                const SizedBox(width: 8),
              ],
              Expanded(flex: 3, child: _o2Field(context)),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: _heField(context)),
            ],
          );
        }

        if (priceController == null) return mixRow;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            mixRow,
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Lines the price field up under O2 rather than under the
                // leading label, matching where the mix row's own fields
                // start.
                if (leading != null)
                  SizedBox(width: (leadingWidth ?? _labelWidth(context)) + 8),
                Expanded(child: _priceField(context)),
              ],
            ),
          ],
        );
      },
    );
  }

  double _labelWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: leading,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }

  Widget _leadingLabel(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8, bottom: 14),
    child: SizedBox(
      width: leadingWidth,
      child: Text(leading!, style: Theme.of(context).textTheme.titleSmall),
    ),
  );

  Widget _pressureField(BuildContext context) => _field(
    controller: pressureController!,
    label: '${context.l10n.gasCalculators_blender_pressure} ($pressureSymbol)',
    onChanged: onPressure!,
  );

  Widget _o2Field(BuildContext context) => _field(
    controller: o2Controller,
    label: '${context.l10n.gasCalculators_blender_o2} (%)',
    onChanged: (_) => onMix(),
    errorText: errorText,
  );

  Widget _heField(BuildContext context) => _field(
    controller: heController,
    label: '${context.l10n.gasCalculators_blender_he} (%)',
    onChanged: (_) => onMix(),
    errorText: errorText,
  );

  /// Like the pressure field, this never shows [errorText]: an invalid O2/He
  /// mix has nothing to do with the price the row's gas costs.
  Widget _priceField(BuildContext context) {
    return TextField(
      controller: priceController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: priceLabel,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: onPriceChanged,
      onEditingComplete: onSave,
      onSubmitted: onSave == null ? null : (_) => onSave!(),
    );
  }

  /// [errorText] is passed in per field rather than read from the widget, so
  /// that only the fields the message applies to carry it.
  Widget _field({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
      onEditingComplete: onSave,
      onSubmitted: onSave == null ? null : (_) => onSave!(),
    );
  }
}
