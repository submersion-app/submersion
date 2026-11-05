import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/card_photo/card_photo_tuning.dart';

/// One theme's overlay opacity over dive card photos, as a percentage
/// slider.
///
/// The value follows the thumb while it is dragged and is saved once, when
/// it is let go, so a drag does not write the setting on every step.
class CardPhotoOverlaySlider extends StatefulWidget {
  const CardPhotoOverlaySlider({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<CardPhotoOverlaySlider> createState() => _CardPhotoOverlaySliderState();
}

class _CardPhotoOverlaySliderState extends State<CardPhotoOverlaySlider> {
  double? _dragging;

  static int get _divisions =>
      ((CardPhotoTuning.overlayMax - CardPhotoTuning.overlayMin) /
              CardPhotoTuning.overlayStep)
          .round();

  static String _percent(double v) => '${(v * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final value = (_dragging ?? widget.value).clamp(
      CardPhotoTuning.overlayMin,
      CardPhotoTuning.overlayMax,
    );
    return ListTile(
      leading: Icon(widget.icon),
      title: Row(
        children: [
          Expanded(child: Text(widget.label)),
          Text(_percent(value)),
        ],
      ),
      subtitle: Slider(
        value: value,
        min: CardPhotoTuning.overlayMin,
        max: CardPhotoTuning.overlayMax,
        divisions: _divisions,
        label: _percent(value),
        semanticFormatterCallback: _percent,
        onChanged: (v) => setState(() => _dragging = v),
        onChangeEnd: (v) {
          setState(() => _dragging = null);
          widget.onChanged(v);
        },
      ),
    );
  }
}
