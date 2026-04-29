import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Visual placeholder shown when a [MediaItem] cannot be displayed on the
/// current device. Renders a grayed thumbnail with an icon and short label
/// describing why.
class UnavailableMediaPlaceholder extends StatelessWidget {
  final UnavailableData data;
  final double iconSize;

  const UnavailableMediaPlaceholder({
    super.key,
    required this.data,
    this.iconSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(data.kind), size: iconSize, color: scheme.outline),
            const SizedBox(height: 4),
            Text(
              _messageFor(context, data),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(UnavailableKind kind) => switch (kind) {
    UnavailableKind.notFound => Icons.broken_image_outlined,
    UnavailableKind.unauthenticated => Icons.lock_outline,
    UnavailableKind.signInRequired => Icons.lock_outline,
    UnavailableKind.fromOtherDevice => Icons.devices_other,
    UnavailableKind.networkError => Icons.cloud_off_outlined,
  };

  String _messageFor(BuildContext context, UnavailableData d) {
    if (d.userMessage != null) return d.userMessage!;
    final l10n = context.l10n;
    return switch (d.kind) {
      UnavailableKind.notFound =>
        l10n.media_unavailablePlaceholder_fileNotFound,
      UnavailableKind.unauthenticated =>
        l10n.media_unavailablePlaceholder_signInRequired,
      UnavailableKind.signInRequired =>
        l10n.media_unavailablePlaceholder_signInRequired,
      UnavailableKind.fromOtherDevice =>
        d.originDeviceLabel != null
            ? l10n.media_unavailablePlaceholder_fromOtherDeviceLabel(
                d.originDeviceLabel!,
              )
            : l10n.media_unavailablePlaceholder_fromOtherDevice,
      UnavailableKind.networkError =>
        l10n.media_unavailablePlaceholder_networkError,
    };
  }
}
