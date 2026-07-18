import 'package:flutter/material.dart';

import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Environment settings for the Setup accordion: altitude with the altitude
/// group indicator. Water type / salinity lands here in later phases.
class PlanEnvironmentSection extends ConsumerWidget {
  const PlanEnvironmentSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(divePlanNotifierProvider);
    final o2Narcotic = ref.watch(settingsProvider.select((s) => s.o2Narcotic));
    final units = UnitFormatter(ref.watch(settingsProvider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AltitudeInput(
          altitude: planState.altitude,
          units: units,
          compact: true,
          onChanged: (value) =>
              ref.read(divePlanNotifierProvider.notifier).updateAltitude(value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.plannerCanvas_o2Narcotic),
          value: o2Narcotic,
          onChanged: (value) =>
              ref.read(settingsProvider.notifier).setO2Narcotic(value),
        ),
      ],
    );
  }
}

/// Altitude input with group indicator for altitude diving.
class _AltitudeInput extends StatefulWidget {
  final double? altitude;
  final UnitFormatter units;
  final bool compact;
  final ValueChanged<double?> onChanged;

  const _AltitudeInput({
    required this.altitude,
    required this.units,
    this.compact = false,
    required this.onChanged,
  });

  @override
  State<_AltitudeInput> createState() => _AltitudeInputState();
}

class _AltitudeInputState extends State<_AltitudeInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.altitude != null
          ? widget.units.convertAltitude(widget.altitude!).toStringAsFixed(0)
          : '',
    );
  }

  @override
  void didUpdateWidget(_AltitudeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if altitude changed externally (not from typing)
    if (oldWidget.altitude != widget.altitude) {
      final newText = widget.altitude != null
          ? widget.units.convertAltitude(widget.altitude!).toStringAsFixed(0)
          : '';
      if (_controller.text != newText) {
        _controller.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final altitudeGroup = AltitudeGroup.fromAltitude(widget.altitude);
    final hasAltitude = widget.altitude != null && widget.altitude! > 0;
    final showGroup = hasAltitude && altitudeGroup != AltitudeGroup.seaLevel;

    final textField = SizedBox(
      width: 80,
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          suffixText: widget.units.altitudeSymbol,
          hintText: '0',
        ),
        keyboardType: TextInputType.number,
        onChanged: (value) {
          if (value.isEmpty) {
            widget.onChanged(null);
          } else {
            final parsed = double.tryParse(value);
            if (parsed != null) {
              final meters = widget.units.altitudeToMeters(parsed);
              widget.onChanged(meters);
            }
          }
        },
      ),
    );

    final groupChip = showGroup
        ? Flexible(
            child: Semantics(
              label: 'Altitude group: ${altitudeGroup.displayName}',
              child: _buildGroupChip(theme, altitudeGroup),
            ),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.compact) ...[
          Row(
            children: [
              const Icon(Icons.terrain, size: 18),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  context.l10n.divePlanner_label_altitude,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              textField,
              if (groupChip != null) ...[const SizedBox(width: 8), groupChip],
            ],
          ),
        ] else
          Row(
            children: [
              const Icon(Icons.terrain, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(context.l10n.divePlanner_label_altitude)),
              const SizedBox(width: 8),
              textField,
              if (groupChip != null) ...[const SizedBox(width: 8), groupChip],
            ],
          ),
        if (showGroup)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              altitudeGroup.rangeDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _getGroupColor(theme, altitudeGroup),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGroupChip(ThemeData theme, AltitudeGroup group) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getGroupColor(theme, group).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _getGroupColor(theme, group).withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        group.displayName,
        style: theme.textTheme.labelSmall?.copyWith(
          color: _getGroupColor(theme, group),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getGroupColor(ThemeData theme, AltitudeGroup group) {
    switch (group.warningLevel) {
      case AltitudeWarningLevel.none:
        return theme.colorScheme.onSurface;
      case AltitudeWarningLevel.info:
        return Colors.blue;
      case AltitudeWarningLevel.caution:
        return Colors.orange;
      case AltitudeWarningLevel.warning:
        return Colors.deepOrange;
      case AltitudeWarningLevel.severe:
        return Colors.red;
    }
  }
}
