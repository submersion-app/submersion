import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/data/services/exif_write_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Dialog for confirming write of dive metadata to photo EXIF.
///
/// Shows a preview of the metadata that will be written and warns
/// that the original photo will be modified.
class WriteMetadataDialog extends StatelessWidget {
  final MediaItem item;
  final AppSettings settings;
  final String? siteName;

  const WriteMetadataDialog({
    super.key,
    required this.item,
    required this.settings,
    this.siteName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final enrichment = item.enrichment;
    final formatter = UnitFormatter(settings);

    final metadata = DiveMetadata.fromMediaItem(item, siteName: siteName);

    return AlertDialog(
      title: const Text('Write Dive Data to Photo'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'The following metadata will be written to the photo:',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Metadata preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Depth
                  if (enrichment?.depthMeters != null)
                    _MetadataRow(
                      icon: Icons.arrow_downward,
                      label: 'Depth',
                      value: formatter.formatDepth(
                        enrichment!.depthMeters,
                        decimals: 1,
                      ),
                    ),

                  // Temperature
                  if (enrichment?.temperatureCelsius != null) ...[
                    const SizedBox(height: 8),
                    _MetadataRow(
                      icon: Icons.thermostat,
                      label: 'Temperature',
                      value: formatter.formatTemperature(
                        enrichment!.temperatureCelsius,
                        decimals: 0,
                      ),
                    ),
                  ],

                  // GPS
                  if (item.latitude != null && item.longitude != null) ...[
                    const SizedBox(height: 8),
                    _MetadataRow(
                      icon: Icons.location_on,
                      label: 'GPS',
                      value:
                          '${item.latitude!.toStringAsFixed(4)}, '
                          '${item.longitude!.toStringAsFixed(4)}',
                    ),
                  ],

                  // Elapsed time
                  if (enrichment?.elapsedSeconds != null) ...[
                    const SizedBox(height: 8),
                    _MetadataRow(
                      icon: Icons.timer_outlined,
                      label: 'Dive time',
                      value: _formatElapsedTime(enrichment!.elapsedSeconds!),
                    ),
                  ],

                  // Site name
                  if (siteName != null && siteName!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MetadataRow(
                      icon: Icons.place,
                      label: 'Site',
                      value: siteName!,
                    ),
                  ],

                  // No data warning
                  if (!metadata.hasData)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No dive data available to write.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will modify the original photo.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: metadata.hasData
              ? () => Navigator.of(context).pop(true)
              : null,
          child: const Text('Write'),
        ),
      ],
    );
  }

  String _formatElapsedTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '+$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

/// Row showing a single metadata item with icon.
class _MetadataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Shows the write metadata dialog and returns true if user confirmed.
Future<bool> showWriteMetadataDialog({
  required BuildContext context,
  required MediaItem item,
  required AppSettings settings,
  String? siteName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) =>
        WriteMetadataDialog(item: item, settings: settings, siteName: siteName),
  );
  return result ?? false;
}
