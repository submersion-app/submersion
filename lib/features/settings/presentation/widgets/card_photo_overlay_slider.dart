import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/card_photo/card_photo_tuning.dart';

/// One theme's overlay opacity over dive card photos, as a percentage
/// slider, with an optional [hint] under it.
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
    this.hint,
  });

  /// How far the slider's track starts in from the slider's edge. Set
  /// explicitly (the default depends on the theme's thumb and overlay
  /// shapes) so the [hint] can start where the track does.
  static const trackInset = 12.0;

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  /// Shown under the slider, lined up with the start of its track.
  final String? hint;

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
    final hint = widget.hint;
    return ListTile(
      leading: Icon(widget.icon),
      title: Row(
        children: [
          Expanded(child: Text(widget.label)),
          Text(_percent(value)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Slider(
            value: value,
            min: CardPhotoTuning.overlayMin,
            max: CardPhotoTuning.overlayMax,
            divisions: _divisions,
            label: _percent(value),
            semanticFormatterCallback: _percent,
            padding: const EdgeInsets.symmetric(
              horizontal: CardPhotoOverlaySlider.trackInset,
              vertical: 12,
            ),
            onChanged: (v) => setState(() => _dragging = v),
            onChangeEnd: (v) {
              setState(() => _dragging = null);
              widget.onChanged(v);
            },
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: CardPhotoOverlaySlider.trackInset,
                end: CardPhotoOverlaySlider.trackInset,
              ),
              child: Text(hint, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
