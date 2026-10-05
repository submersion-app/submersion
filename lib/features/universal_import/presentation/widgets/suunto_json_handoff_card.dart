import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:submersion/core/services/suunto_cloud/suunto_json_file_reader.dart';
import 'package:submersion/features/import_wizard/presentation/suunto_file_import_navigation.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shown by the universal import wizard's file-selection step when
/// [FormatDetector] recognises a Suunto app JSON export (issue #1445). The
/// format is a hand-off (`ImportFormat.isHandoff`): the Suunto importer
/// reads it the way the Suunto Cloud import does, recorded route included,
/// so this card passes the file there instead of advancing the wizard.
class SuuntoJsonHandoffCard extends StatelessWidget {
  const SuuntoJsonHandoffCard({
    super.key,
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      key: const ValueKey('suunto-json-handoff-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.scuba_diving, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.suuntoJson_handoff_recognized,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.suuntoJson_handoff_description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('suunto-json-handoff-import'),
                onPressed: () => openSuuntoFileImport(context, [
                  SuuntoJsonFile(name: fileName, bytes: bytes),
                ]),
                child: Text(l10n.suuntoJson_handoff_importButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
