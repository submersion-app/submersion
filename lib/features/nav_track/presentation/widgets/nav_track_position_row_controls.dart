import 'package:flutter/material.dart';

/// One selectable suggestion in a [NavTrackPositionRowControls] row: a key,
/// a label, whether it is the value currently in effect, and what choosing
/// it does.
class NavTrackPositionOption {
  const NavTrackPositionOption({
    required this.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String key;
  final String label;
  final bool selected;
  final VoidCallback onSelected;
}

/// The "Start:"/"Ende:" row on the route alignment page: one shared widget
/// so both halves of the panel share a single visual language, instead of
/// each row building its own near-identical button+chips markup. A primary
/// button starts the crosshair placement flow; the chips are suggestions
/// the app already knows (dive entry, site, a detected GPS fix, or a fixed
/// set of end modes). Both the button and every chip take their
/// selected/checked look directly from whether they are the value
/// currently in effect, the same signal a single-value dropdown would give
/// for free.
class NavTrackPositionRowControls extends StatelessWidget {
  const NavTrackPositionRowControls({
    super.key,
    required this.label,
    required this.placeKey,
    required this.placeLabel,
    required this.placeSelected,
    required this.onPlace,
    required this.options,
  });

  final String label;
  final String placeKey;
  final String placeLabel;
  final bool placeSelected;
  final VoidCallback onPlace;
  final List<NavTrackPositionOption> options;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            placeSelected
                ? FilledButton.icon(
                    key: ValueKey(placeKey),
                    onPressed: onPlace,
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(placeLabel),
                  )
                : FilledButton.tonal(
                    key: ValueKey(placeKey),
                    onPressed: onPlace,
                    child: Text(placeLabel),
                  ),
            for (final option in options)
              FilterChip(
                key: ValueKey(option.key),
                label: Text(option.label),
                selected: option.selected,
                onSelected: (_) => option.onSelected(),
              ),
          ],
        ),
      ],
    );
  }
}
