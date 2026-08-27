// Read-only preview of a parsed manifest (Phase 3b, Task 13).
//
// Renders the detected format chip (with override dropdown), the entry
// count + skipped-warnings count, and the first 5 entries
// (caption / url / takenAt). The format-chip dropdown forwards user
// selections back through [onFormatOverrideChanged] so the panel can
// re-fetch with the override.

import 'package:flutter/material.dart';

import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';

/// Cap on entries rendered in the preview list. Mirrors the plan's
/// "first 5 entries" requirement.
const int kManifestPreviewLimit = 5;

class ManifestPreviewPane extends StatelessWidget {
  const ManifestPreviewPane({
    super.key,
    required this.result,
    required this.formatOverride,
    required this.onFormatOverrideChanged,
  });

  final ManifestParseResult result;
  final ManifestFormat? formatOverride;
  final ValueChanged<ManifestFormat?> onFormatOverrideChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = result.entries.take(kManifestPreviewLimit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // TODO(media): l10n
            Text('Format:', style: theme.textTheme.labelLarge),
            const SizedBox(width: 8),
            DropdownButton<ManifestFormat>(
              value: formatOverride ?? result.format,
              onChanged: onFormatOverrideChanged,
              items: ManifestFormat.values
                  .map(
                    (f) => DropdownMenuItem<ManifestFormat>(
                      value: f,
                      child: Text(f.displayName),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // TODO(media): l10n, pluralization
        Text(
          '${result.entries.length} '
          '${result.entries.length == 1 ? 'entry' : 'entries'} detected',
          style: theme.textTheme.bodyMedium,
        ),
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 4),
          // TODO(media): l10n, pluralization
          Text(
            '${result.warnings.length} '
            '${result.warnings.length == 1 ? 'entry' : 'entries'} skipped',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (final entry in preview)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.caption ?? entry.entryKey,
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  entry.url,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.takenAt != null)
                  Text(
                    entry.takenAt!.toIso8601String(),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
