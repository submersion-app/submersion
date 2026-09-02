import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/value_objects/import_preview.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/widgets/network_thumbnail.dart';

/// The leading art for one pre-import review row.
///
/// The only place the gallery and network byte stacks meet: it switches on
/// [ImportPreview] so `MediaImportReviewPage` imports neither. A candidate
/// with no preview gets nothing at all rather than an empty box, because
/// `ListTile` indents its title for any non-null leading widget.
class ImportPreviewThumbnail extends ConsumerWidget {
  const ImportPreviewThumbnail({
    super.key,
    required this.preview,
    this.size = 48,
  });

  final ImportPreview preview;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: size,
      height: size,
      child: switch (preview) {
        AssetImportPreview(:final assetId) => _AssetThumbnail(
          assetId: assetId,
          size: size,
        ),
        UrlImportPreview(:final url) => NetworkThumbnail(url: url, size: size),
      },
    );
  }
}

/// Bytes for a device-library asset. The provider is the same one the picker
/// grid uses, so a thumbnail the user already scrolled past is a cache hit
/// rather than a second PhotoKit round trip.
class _AssetThumbnail extends ConsumerWidget {
  const _AssetThumbnail({required this.assetId, required this.size});

  final String assetId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(assetThumbnailProvider(assetId));
    return bytes.when(
      data: (data) => data == null
          ? _Placeholder(size: size, icon: Icons.broken_image_outlined)
          : Image.memory(
              data,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _Placeholder(size: size, icon: Icons.broken_image_outlined),
            ),
      loading: () => _Placeholder(size: size),
      error: (_, _) =>
          _Placeholder(size: size, icon: Icons.broken_image_outlined),
    );
  }
}

/// A neutral box while bytes are in flight, or with an icon once they are
/// known not to be coming.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size, this.icon});

  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: icon == null ? null : Icon(icon, size: size * 0.6),
    );
  }
}
