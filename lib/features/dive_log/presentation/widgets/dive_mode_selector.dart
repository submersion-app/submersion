import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A segmented button for selecting the dive mode (OC, CCR, SCR).
///
/// This widget provides a clear, visual way for divers to specify their
/// breathing apparatus type, which affects how ppO₂ and gas consumption
/// are calculated throughout the profile analysis.
class DiveModeSelector extends StatelessWidget {
  /// The currently selected dive mode.
  final DiveMode selectedMode;

  /// Callback when the mode changes.
  final ValueChanged<DiveMode> onChanged;

  /// Whether the selector is enabled.
  final bool enabled;

  const DiveModeSelector({
    super.key,
    required this.selectedMode,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveLog_diveMode_title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<DiveMode>(
          segments: DiveMode.values.map((mode) {
            return ButtonSegment<DiveMode>(
              value: mode,
              label: Text(mode.name.toUpperCase()),
              tooltip: mode.displayName,
              icon: Icon(_getIconForMode(mode), size: 18),
            );
          }).toList(),
          selected: {selectedMode},
          onSelectionChanged: enabled
              ? (selection) {
                  if (selection.isNotEmpty) {
                    onChanged(selection.first);
                  }
                }
              : null,
          showSelectedIcon: false,
        ),
        const SizedBox(height: 4),
        Semantics(
          label:
              'Selected mode: ${selectedMode.name.toUpperCase()}, ${_getDescriptionForMode(context, selectedMode)}',
          child: Text(
            _getDescriptionForMode(context, selectedMode),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIconForMode(DiveMode mode) {
    switch (mode) {
      case DiveMode.oc:
        return Icons.air; // Open circuit - breathing from tanks
      case DiveMode.ccr:
        return Icons.loop; // Closed circuit - loop symbol
      case DiveMode.scr:
        return Icons.sync_alt; // Semi-closed - partial loop
    }
  }

  String _getDescriptionForMode(BuildContext context, DiveMode mode) {
    switch (mode) {
      case DiveMode.oc:
        return context.l10n.diveLog_diveMode_ocDescription;
      case DiveMode.ccr:
        return context.l10n.diveLog_diveMode_ccrDescription;
      case DiveMode.scr:
        return context.l10n.diveLog_diveMode_scrDescription;
    }
  }
}
