import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Terminal view for a saved computer the app cannot download from directly.
///
/// A computer that reached the library through a file or cloud import has no
/// stored Bluetooth address or USB descriptor, so there is nothing to connect
/// to. Garmin watches are the common case: they are not libdivecomputer
/// devices at all, and on Windows they attach over MTP, which the app cannot
/// read. Their dives arrive as FIT files, so the view points at the file
/// import instead of leaving the download spinning (issue #1858).
class DcNoDirectDownloadView extends StatelessWidget {
  const DcNoDirectDownloadView({
    super.key,
    required this.computer,
    required this.onImportFromFile,
    required this.onDone,
  });

  final DiveComputer computer;
  final VoidCallback onImportFromFile;
  final VoidCallback onDone;

  bool get _isGarmin => computer.manufacturer?.trim().toLowerCase() == 'garmin';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.secondaryContainer,
              ),
              child: Icon(
                Icons.file_open_outlined,
                size: 64,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.importWizard_dc_noDirectDownload,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isGarmin
                  ? l10n.importWizard_dc_noDirectDownloadGarminBody
                  : l10n.importWizard_dc_noDirectDownloadBody(
                      computer.displayName,
                    ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onImportFromFile,
              icon: const Icon(Icons.upload_file),
              label: Text(l10n.importWizard_dc_importFromFile),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onDone,
              child: Text(l10n.universalImport_action_done),
            ),
          ],
        ),
      ),
    );
  }
}
