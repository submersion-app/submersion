import 'package:flutter/material.dart';

/// A dialog that allows the user to pick two colors (start and end) for a
/// custom gradient using HSV sliders. Returns `(int, int)?` representing
/// the ARGB values of the start and end colors, or null if cancelled.
class CustomGradientDialog extends StatefulWidget {
  final Color? initialStart;
  final Color? initialEnd;

  const CustomGradientDialog({super.key, this.initialStart, this.initialEnd});

  @override
  State<CustomGradientDialog> createState() => _CustomGradientDialogState();
}

class _CustomGradientDialogState extends State<CustomGradientDialog> {
  late HSVColor _startHsv;
  late HSVColor _endHsv;
  bool _editingStart = true;

  @override
  void initState() {
    super.initState();
    _startHsv = HSVColor.fromColor(
      widget.initialStart ?? const Color(0xFF4DD0E1),
    );
    _endHsv = HSVColor.fromColor(widget.initialEnd ?? const Color(0xFF0D1B2A));
  }

  HSVColor get _activeHsv => _editingStart ? _startHsv : _endHsv;

  void _updateActiveHsv(HSVColor hsv) {
    setState(() {
      if (_editingStart) {
        _startHsv = hsv;
      } else {
        _endHsv = hsv;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startColor = _startHsv.toColor();
    final endColor = _endHsv.toColor();

    return AlertDialog(
      title: const Text('Custom Gradient'),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Color wells
              Row(
                children: [
                  Expanded(
                    child: _ColorWell(
                      label: 'Start',
                      color: startColor,
                      isSelected: _editingStart,
                      onTap: () => setState(() => _editingStart = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ColorWell(
                      label: 'End',
                      color: endColor,
                      isSelected: !_editingStart,
                      onTap: () => setState(() => _editingStart = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // HSV sliders
              _HsvSlider(
                label: 'Hue',
                value: _activeHsv.hue,
                min: 0,
                max: 360,
                activeColor: _activeHsv.toColor(),
                gradient: _buildHueGradient(),
                onChanged: (v) =>
                    _updateActiveHsv(_activeHsv.withHue(v.clamp(0, 360))),
              ),
              const SizedBox(height: 8),
              _HsvSlider(
                label: 'Saturation',
                value: _activeHsv.saturation,
                min: 0,
                max: 1,
                activeColor: _activeHsv.toColor(),
                gradient: LinearGradient(
                  colors: [
                    _activeHsv.withSaturation(0).toColor(),
                    _activeHsv.withSaturation(1).toColor(),
                  ],
                ),
                onChanged: (v) =>
                    _updateActiveHsv(_activeHsv.withSaturation(v.clamp(0, 1))),
              ),
              const SizedBox(height: 8),
              _HsvSlider(
                label: 'Brightness',
                value: _activeHsv.value,
                min: 0,
                max: 1,
                activeColor: _activeHsv.toColor(),
                gradient: LinearGradient(
                  colors: [
                    _activeHsv.withValue(0).toColor(),
                    _activeHsv.withValue(1).toColor(),
                  ],
                ),
                onChanged: (v) =>
                    _updateActiveHsv(_activeHsv.withValue(v.clamp(0, 1))),
              ),
              const SizedBox(height: 16),
              // Preview gradient bar
              Container(
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(colors: [startColor, endColor]),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Preview',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop((startColor.toARGB32(), endColor.toARGB32()));
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  LinearGradient _buildHueGradient() {
    const steps = 7;
    final colors = List<Color>.generate(
      steps,
      (i) => HSVColor.fromAHSV(1, i * 360 / (steps - 1), 1, 1).toColor(),
    );
    return LinearGradient(colors: colors);
  }
}

/// A tappable color well showing a solid color with a label.
class _ColorWell extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorWell({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.3),
                width: isSelected ? 3 : 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A slider with a gradient track background and a label.
class _HsvSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Color activeColor;
  final LinearGradient gradient;
  final ValueChanged<double> onChanged;

  const _HsvSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.activeColor,
    required this.gradient,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Stack(
          alignment: Alignment.center,
          children: [
            // Gradient track
            Container(
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            // Slider overlay
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 12,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: activeColor,
                overlayColor: activeColor.withValues(alpha: 0.2),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                  elevation: 2,
                ),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
