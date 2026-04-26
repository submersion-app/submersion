import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(data.kind), size: iconSize, color: scheme.outline),
          const SizedBox(height: 4),
          Text(
            _messageFor(data),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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

  String _messageFor(UnavailableData d) {
    if (d.userMessage != null) return d.userMessage!;
    return switch (d.kind) {
      UnavailableKind.notFound => 'File not found',
      UnavailableKind.unauthenticated => 'Sign in to view',
      UnavailableKind.signInRequired => 'Sign in to view',
      UnavailableKind.fromOtherDevice =>
        d.originDeviceLabel != null
            ? 'From ${d.originDeviceLabel}'
            : 'From another device',
      UnavailableKind.networkError => "Couldn't connect",
    };
  }
}
