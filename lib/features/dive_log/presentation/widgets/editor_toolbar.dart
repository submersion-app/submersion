import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Mode selector toolbar for the profile editor.
///
/// Displays a segmented button with four editing modes:
/// Select, Smooth, Cleanup, and Draw. Where the labels do not fit on one
/// line each, as on a phone in portrait, it shows the icons alone and names
/// each mode in its tooltip (issue #5056).
class EditorToolbar extends StatelessWidget {
  final EditorMode mode;
  final void Function(EditorMode) onModeChanged;

  const EditorToolbar({
    super.key,
    required this.mode,
    required this.onModeChanged,
  });

  /// What a Material 3 segment adds to its label: 12 and 16 px of padding,
  /// the 18 px icon, the 8 px gap after it and a 1 px border, rounded up.
  /// Larger text shrinks the padding and gap, so this errs towards icons.
  static const double _segmentChrome = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final modes = [
      (
        EditorMode.select,
        Icons.touch_app,
        l10n.diveLog_profileEditor_mode_select,
      ),
      (
        EditorMode.smooth,
        Icons.auto_fix_high,
        l10n.diveLog_profileEditor_mode_smooth,
      ),
      (
        EditorMode.outlier,
        Icons.cleaning_services,
        l10n.diveLog_profileEditor_mode_cleanup,
      ),
      (EditorMode.draw, Icons.draw, l10n.diveLog_profileEditor_mode_draw),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showLabels = _labelsFit(context, [
            for (final (_, _, label) in modes) label,
          ], constraints.maxWidth);
          return SegmentedButton<EditorMode>(
            // The selected check replaces the segment's icon, which alone
            // names the mode when the labels are gone.
            showSelectedIcon: showLabels,
            segments: [
              for (final (value, icon, label) in modes)
                ButtonSegment(
                  value: value,
                  icon: Icon(icon),
                  label: showLabels ? Text(label) : null,
                  tooltip: showLabels ? null : label,
                ),
            ],
            selected: {mode},
            onSelectionChanged: (selected) {
              onModeChanged(selected.first);
            },
          );
        },
      ),
    );
  }

  /// Whether every segment can show its label on one line in [width]. A
  /// segmented button sizes each segment to its widest one.
  bool _labelsFit(BuildContext context, List<String> labels, double width) {
    final style = Theme.of(context).textTheme.labelLarge;
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return labels.length * (widest + _segmentChrome) <= width;
  }
}
