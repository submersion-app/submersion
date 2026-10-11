import 'package:flutter/material.dart';

import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

/// The dive edit form's visibility input (issue #3226): a band pick or a
/// precise number, with a Range | Precise switch under it. Stateless; the
/// page owns the values and decides what a save writes
/// ([resolveVisibilityEntry]).
class VisibilityInput extends StatelessWidget {
  const VisibilityInput({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.controller,
    required this.depthSymbol,
    required this.inputValidator,
    required this.onPreciseChanged,
    required this.band,
    required this.onBandChanged,
    required this.caption,
  });

  final VisibilityInputMode mode;
  final ValueChanged<VisibilityInputMode> onModeChanged;
  final TextEditingController controller;
  final String depthSymbol;
  final String? Function(String?)? inputValidator;
  final ValueChanged<String> onPreciseChanged;
  final VisibilityBand? band;
  final ValueChanged<VisibilityBand?> onBandChanged;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = l10n.diveLog_edit_label_visibility;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (mode) {
          VisibilityInputMode.precise => FormRow.text(
            label: label,
            controller: controller,
            suffixText: depthSymbol,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // No input filter: stripping '-' would turn "-5", which saves as
            // unknown, into 5 m. Unreadable text would otherwise save as
            // "unknown" too and erase a measured visibility (#1900).
            inputValidator: inputValidator,
            onChanged: onPreciseChanged,
          ),
          VisibilityInputMode.range => FormRow.custom(
            label: label,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final b in VisibilityBand.values)
                  ChoiceChip(
                    label: Text(visibilityBandName(b, l10n)),
                    selected: band == b,
                    onSelected: (selected) =>
                        onBandChanged(selected ? b : null),
                  ),
              ],
            ),
          ),
        },
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  caption ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              SegmentedButton<VisibilityInputMode>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: VisibilityInputMode.range,
                    label: Text(l10n.diveLog_edit_visibility_modeRange),
                  ),
                  ButtonSegment(
                    value: VisibilityInputMode.precise,
                    label: Text(l10n.diveLog_edit_visibility_modePrecise),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) => onModeChanged(s.first),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
