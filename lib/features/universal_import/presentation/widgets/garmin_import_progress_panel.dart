import 'package:flutter/material.dart';

import 'package:submersion/features/universal_import/data/models/garmin_import_progress.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Says which stage an import from a Garmin watch is at, with a bar that
/// fills while files are copied and checked, and runs while the watch is
/// found and scanned, where there is nothing to count (issue #4223).
class GarminImportProgressPanel extends StatelessWidget {
  const GarminImportProgressPanel({super.key, required this.progress});

  final GarminImportProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _label(context),
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress.hasCount ? progress.fraction : null,
        ),
      ],
    );
  }

  String _label(BuildContext context) {
    final l10n = context.l10n;
    return switch (progress.phase) {
      GarminImportPhase.lookingForWatch =>
        l10n.universalImport_label_lookingForWatch,
      GarminImportPhase.scanning =>
        l10n.universalImport_label_scanningWatchActivity(
          progress.deviceName ?? 'Garmin',
        ),
      GarminImportPhase.copying => l10n.universalImport_label_readingWatchFiles(
        progress.current,
        progress.total,
      ),
      GarminImportPhase.checking => l10n.universalImport_label_checkingForDives(
        progress.current,
        progress.total,
      ),
    };
  }
}
