import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/media_share_temp_file.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Full-screen in-app viewer for PDF document attachments.
///
/// Bytes come through [mediaBytesProvider], which resolves the row against
/// the source it points at and falls back to the media store, so a PDF views
/// identically whether it lives behind a local bookmark, a SAF URI, a plain
/// path, or only in the cloud store.
class DocumentViewerPage extends ConsumerStatefulWidget {
  final MediaItem item;

  const DocumentViewerPage({super.key, required this.item});

  @override
  ConsumerState<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends ConsumerState<DocumentViewerPage> {
  /// pdfrx needs its one-time Flutter bootstrap before the first PdfViewer
  /// builds; the call is idempotent and cheap afterwards.
  late final Future<void> _engineReady = pdfrxFlutterInitialize();

  @override
  Widget build(BuildContext context) {
    final resolvedAsync = ref.watch(mediaBytesProvider(widget.item));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item.originalFilename ??
              context.l10n.media_documentViewer_title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: context.l10n.media_photoViewer_shareTooltip,
            onPressed: () => _share(context),
          ),
        ],
      ),
      body: resolvedAsync.when(
        data: (resolved) {
          if (resolved.isUnavailable || resolved.bytes == null) {
            return _UnavailableState(item: widget.item);
          }
          return FutureBuilder<void>(
            future: _engineReady,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _UnavailableState(item: widget.item);
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return PdfViewer.data(
                resolved.bytes!,
                sourceName: widget.item.id,
                params: PdfViewerParams(
                  // A corrupt file must degrade to the unavailable state,
                  // not crash the page.
                  errorBannerBuilder: (context, error, stackTrace, _) =>
                      _UnavailableState(item: widget.item),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _UnavailableState(item: widget.item),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final l10n = context.l10n;
    try {
      final resolved = await ref.read(mediaBytesProvider(widget.item).future);
      if (resolved.isUnavailable || resolved.bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.media_photoViewer_cannotShare)),
          );
        }
        return;
      }
      final file = await writeShareTempFile(widget.item, resolved.bytes!);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: widget.item.shareMimeType)],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.media_photoViewer_failedToShare('$e'))),
        );
      }
    }
  }
}

/// Shown when the document's bytes cannot be resolved on this device (or
/// the file is corrupt). Mentions the origin device when known.
class _UnavailableState extends StatelessWidget {
  final MediaItem item;

  const _UnavailableState({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 64,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.media_documentViewer_unavailable,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (item.originDeviceId != null) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.media_documentViewer_availableOnOriginDevice,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
