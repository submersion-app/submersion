import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/data/services/metadata_write_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Result from the write metadata dialog.
class WriteMetadataResult {
  /// Whether the user confirmed the write.
  final bool confirmed;

  /// For videos, whether to keep the original after creating a new one.
  final bool keepOriginal;

  const WriteMetadataResult({
    required this.confirmed,
    this.keepOriginal = false,
  });
}

/// Dialog for confirming write of dive metadata to photo/video.
///
/// Shows a preview of the metadata that will be written and warns
/// about the modification. For videos, offers option to keep or delete original.
class WriteMetadataDialog extends StatefulWidget {
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
  State<WriteMetadataDialog> createState() => _WriteMetadataDialogState();
}

class _WriteMetadataDialogState extends State<WriteMetadataDialog> {
  bool _keepOriginal = true;

  bool get _isVideo => widget.item.mediaType == MediaType.video;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final enrichment = widget.item.enrichment;
    final formatter = UnitFormatter(widget.settings);

    final metadata = DiveMediaMetadata.fromMediaItem(
      widget.item,
      siteName: widget.siteName,
    );

    final mediaType = _isVideo ? 'video' : 'photo';
    final title = 'Write Dive Data to ${_isVideo ? 'Video' : 'Photo'}';

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'The following metadata will be written to the $mediaType:',
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
                  if (widget.item.latitude != null &&
                      widget.item.longitude != null) ...[
                    const SizedBox(height: 8),
                    _MetadataRow(
                      icon: Icons.location_on,
                      label: 'GPS',
                      value:
                          '${widget.item.latitude!.toStringAsFixed(4)}, '
                          '${widget.item.longitude!.toStringAsFixed(4)}',
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
                  if (widget.siteName != null &&
                      widget.siteName!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MetadataRow(
                      icon: Icons.place,
                      label: 'Site',
                      value: widget.siteName!,
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

            // Warning - different for video vs photo
            _buildWarningSection(colorScheme, textTheme),

            // Video-specific: keep original option
            if (_isVideo) ...[
              const SizedBox(height: 12),
              _buildKeepOriginalOption(colorScheme, textTheme),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(const WriteMetadataResult(confirmed: false)),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: metadata.hasData
              ? () => Navigator.of(context).pop(
                  WriteMetadataResult(
                    confirmed: true,
                    keepOriginal: _isVideo ? _keepOriginal : false,
                  ),
                )
              : null,
          child: const Text('Write'),
        ),
      ],
    );
  }

  Widget _buildWarningSection(ColorScheme colorScheme, TextTheme textTheme) {
    final String warningText;
    final IconData warningIcon;

    if (_isVideo) {
      warningText =
          'A new video will be created with the metadata. '
          'Video metadata cannot be modified in-place.';
      warningIcon = Icons.info_outline;
    } else {
      warningText = 'This will modify the original photo.';
      warningIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isVideo
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            warningIcon,
            color: _isVideo ? colorScheme.primary : colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              warningText,
              style: textTheme.bodySmall?.copyWith(
                color: _isVideo ? colorScheme.primary : colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeepOriginalOption(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Keep original video', style: textTheme.bodyMedium),
          ),
          Switch(
            value: _keepOriginal,
            onChanged: (value) => setState(() => _keepOriginal = value),
          ),
        ],
      ),
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

/// Shows the write metadata dialog and returns the result.
///
/// Returns a [WriteMetadataResult] with:
/// - `confirmed`: true if user wants to proceed with the write
/// - `keepOriginal`: for videos, whether to keep the original video
Future<WriteMetadataResult> showWriteMetadataDialog({
  required BuildContext context,
  required MediaItem item,
  required AppSettings settings,
  String? siteName,
}) async {
  final result = await showDialog<WriteMetadataResult>(
    context: context,
    builder: (_) =>
        WriteMetadataDialog(item: item, settings: settings, siteName: siteName),
  );
  return result ?? const WriteMetadataResult(confirmed: false);
}
