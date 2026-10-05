import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/pdf_page_renderer.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_byte_retention.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';

/// What a large PDF card asks for: the item and the render size bucket.
typedef PdfPreviewRequest = ({MediaItem item, int maxDimension});

const _buckets = [1024, 1536, 2048];

/// The render size for a card [logicalWidth] wide: the physical width
/// rounded up to a bucket, capped at the largest. Bucketing keeps a window
/// resize from re-rendering the document at every intermediate width.
int pdfPreviewBucket(double logicalWidth, double devicePixelRatio) {
  final physical = logicalWidth * devicePixelRatio;
  for (final bucket in _buckets) {
    if (physical <= bucket) return bucket;
  }
  return _buckets.last;
}

/// Page 1 of a PDF attachment at card width, with its page count
/// (issue #1039). Null when the PDF cannot be read or rendered here.
final pdfLargePreviewProvider = FutureProvider.autoDispose
    .family<PdfPagePreview?, PdfPreviewRequest>((ref, request) async {
      // Held past an unwatched gap (a card rebuilding at another size, the
      // diver stepping away mid-render): without it auto-disposal lands
      // between the awaits, the bytes read below fails on a dead ref, and
      // the finished render is thrown away. The preview is a few hundred
      // kilobytes, so the thumbnail window fits.
      retainFor(ref, thumbnailRetention);
      final service = ref.watch(pdfThumbnailServiceProvider);
      return service.previewFor(
        request.item,
        maxDimension: request.maxDimension,
        bytes: () async =>
            (await ref.read(mediaBytesProvider(request.item).future)).bytes,
      );
    });
