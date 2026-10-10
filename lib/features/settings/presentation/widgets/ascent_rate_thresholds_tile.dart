import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The decompression settings' "Ascent rate" section: header, explanation
/// and [AscentRateThresholdsTile].
class AscentRateSection extends StatelessWidget {
  const AscentRateSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settings_decompression_header_ascentRate,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            context.l10n.settings_decompression_header_ascentRate_subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Card(child: AscentRateThresholdsTile()),
      ],
    );
  }
}

/// The "Ascent rate thresholds" entry of the decompression settings: the
/// warning and critical rates the profile's ascent-rate colours and events
/// use (issue #3091), opening [AscentRateThresholdsDialog] to edit them.
///
/// The safety review's rapid-ascent rule does not read these. It keeps fixed
/// limits so that changing a preference never rewrites reviewed history.
class AscentRateThresholdsTile extends ConsumerWidget {
  const AscentRateThresholdsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return ListTile(
      leading: const Icon(Icons.trending_up),
      title: Text(context.l10n.settings_decompression_ascentRateThresholds),
      subtitle: Text(
        context.l10n.settings_decompression_ascentRateThresholds_subtitle(
          units.formatDepthRate(settings.ascentRateCritical, decimals: 0),
          units.formatDepthRate(settings.ascentRateWarning, decimals: 0),
        ),
      ),
      trailing: const Icon(Icons.edit),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => AscentRateThresholdsDialog(
          initialWarning: settings.ascentRateWarning,
          initialCritical: settings.ascentRateCritical,
          formatRate: (rate) => units.formatDepthRate(rate, decimals: 0),
          onSave: (warning, critical) {
            // Saving what is already stored is not a change: writing it
            // anyway would queue the synced settings row for nothing.
            if (warning == settings.ascentRateWarning &&
                critical == settings.ascentRateCritical) {
              return;
            }
            ref
                .read(settingsProvider.notifier)
                .setAscentRateThresholds(warning: warning, critical: critical);
          },
        ),
      ),
    );
  }
}

/// Edits the warning and critical ascent rates, in whole m/min across the
/// ranges [SettingsNotifier] accepts.
///
/// The two sliders stay ordered as they move: pushing warning past critical
/// carries critical up with it, and pulling critical below warning carries
/// warning down, so what the diver sees is what gets saved.
class AscentRateThresholdsDialog extends StatefulWidget {
  const AscentRateThresholdsDialog({
    super.key,
    required this.initialWarning,
    required this.initialCritical,
    required this.formatRate,
    required this.onSave,
  });

  /// Rates in m/min.
  final double initialWarning;
  final double initialCritical;

  /// Renders a rate in m/min in the diver's depth unit.
  final String Function(double metersPerMin) formatRate;
  final void Function(double warning, double critical) onSave;

  @override
  State<AscentRateThresholdsDialog> createState() =>
      _AscentRateThresholdsDialogState();
}

class _AscentRateThresholdsDialogState
    extends State<AscentRateThresholdsDialog> {
  static const double _warningMin = SettingsNotifier.ascentRateWarningMin;
  static const double _warningMax = SettingsNotifier.ascentRateWarningMax;
  static const double _criticalMin = SettingsNotifier.ascentRateCriticalMin;
  static const double _criticalMax = SettingsNotifier.ascentRateCriticalMax;

  late double _warning = _snap(widget.initialWarning, _warningMin, _warningMax);
  late double _critical = _snap(
    widget.initialCritical,
    _criticalMin,
    _criticalMax,
  );

  /// A stored value kept inside the slider's range. Not rounded onto the
  /// slider's grid: a synced 9.5 must survive a save that only moved the
  /// other slider.
  static double _snap(double value, double min, double max) =>
      value.clamp(min, max);

  void _setWarning(double value) {
    setState(() {
      _warning = value;
      if (_critical < value) {
        _critical = value.clamp(_criticalMin, _criticalMax);
      }
    });
  }

  void _setCritical(double value) {
    setState(() {
      _critical = value;
      if (_warning > value) _warning = value.clamp(_warningMin, _warningMax);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.settings_decompression_ascentRateThresholds),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(
            label: l10n.settings_decompression_ascentRateWarning,
            child: Slider(
              key: const ValueKey('ascent-rate-warning'),
              value: _warning,
              min: _warningMin,
              max: _warningMax,
              divisions: (_warningMax - _warningMin).round(),
              label: widget.formatRate(_warning),
              onChanged: _setWarning,
            ),
            value: _warning,
          ),
          _row(
            label: l10n.settings_decompression_ascentRateCritical,
            child: Slider(
              key: const ValueKey('ascent-rate-critical'),
              value: _critical,
              min: _criticalMin,
              max: _criticalMax,
              divisions: (_criticalMax - _criticalMin).round(),
              label: widget.formatRate(_critical),
              onChanged: _setCritical,
            ),
            value: _critical,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.settings_decompression_dialog_cancel),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_warning, _critical);
            Navigator.of(context).pop();
          },
          child: Text(l10n.settings_decompression_dialog_save),
        ),
      ],
    );
  }

  Widget _row({
    required String label,
    required Widget child,
    required double value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              widget.formatRate(value),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        child,
      ],
    );
  }
}
