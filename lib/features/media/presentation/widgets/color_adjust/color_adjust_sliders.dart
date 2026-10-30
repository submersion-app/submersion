import 'package:flutter/material.dart';

/// One labelled slider row of the Adjust color panel (issue #3520).
///
/// [onChanged] draws the change live; [onChangeEnd] saves it, so a drag
/// writes the synced row once, not once per frame. A null [onChanged]
/// disables the row.
class ColorAdjustSlider extends StatelessWidget {
  const ColorAdjustSlider({
    super.key,
    required this.sliderKey,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    this.min = -1,
    this.max = 1,
  });

  /// Key of the [Slider] itself, for finding one row among several.
  final Key sliderKey;
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: Slider(
            key: sliderKey,
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onChanged == null ? null : onChangeEnd,
          ),
        ),
      ],
    );
  }
}
