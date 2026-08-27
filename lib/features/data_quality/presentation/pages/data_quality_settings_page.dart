import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/data_quality/domain/detectors/quality_detector_registry.dart';
import 'package:submersion/features/data_quality/presentation/providers/quality_detector_toggles.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_message.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class DataQualitySettingsPage extends ConsumerWidget {
  const DataQualitySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final disabled = ref.watch(qualityDetectorTogglesProvider);
    final notifier = ref.read(qualityDetectorTogglesProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dataQuality_settings_title)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.dataQuality_settings_subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final d in kQualityDetectors)
            SwitchListTile(
              title: Text(detectorTitle(l10n, d.id)),
              value: !disabled.contains(d.id),
              onChanged: (v) => notifier.setEnabled(d.id, v),
            ),
        ],
      ),
    );
  }
}
