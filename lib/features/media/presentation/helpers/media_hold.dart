import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

/// What a picker hands a sitting on a dive or a site in place of writing
/// (issue #4527, plan 6): the rows it would write, shown as tiles until Save.
sealed class HeldMediaAdd {
  const HeldMediaAdd();

  /// The row as the card draws it before it is written.
  MediaItem get preview;
}

/// A row built as the picker would write it, under a fresh id of its own,
/// with its enrichment when it has one.
final class HeldMediaRow extends HeldMediaAdd {
  const HeldMediaRow(this.prepared);

  final PreparedMedia prepared;

  @override
  MediaItem get preview => prepared.item;
}

/// Network media fetched at once (a bad link is reported then) and
/// inserted at Save by the fetch pipeline.
final class HeldNetworkMedia extends HeldMediaAdd {
  const HeldNetworkMedia(this.request, this.preview);

  final NetworkInsertRequest request;

  @override
  final MediaItem preview;
}

/// Takes what a picker opened from a sitting would have written.
typedef MediaHoldSink = void Function(List<HeldMediaAdd> adds);

/// The row [request] becomes, drawn before it is written: a network
/// photo under a fresh id, at the time the fetch found for it.
MediaItem networkPreview(NetworkInsertRequest request) {
  final media = request.media;
  final now = DateTime.now();
  return MediaItem(
    id: const Uuid().v4(),
    diveId: request.diveId,
    siteId: request.siteId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.networkUrl,
    url: media.result?.url ?? media.uri.toString(),
    takenAt: media.takenAt ?? now,
    width: media.entry?.width ?? media.result?.width,
    height: media.entry?.height ?? media.result?.height,
    createdAt: now,
    updatedAt: now,
  );
}

/// Hands the photo picker's tabs the sitting they hold their picks for
/// (issue #4527). With none above them they write at once, as always.
class MediaHoldScope extends InheritedWidget {
  const MediaHoldScope({super.key, required this.sink, required super.child});

  final MediaHoldSink sink;

  static MediaHoldSink? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MediaHoldScope>()?.sink;

  /// [child] under [sink], or [child] alone when there is none.
  static Widget wrap(MediaHoldSink? sink, Widget child) =>
      sink == null ? child : MediaHoldScope(sink: sink, child: child);

  @override
  bool updateShouldNotify(MediaHoldScope oldWidget) => false;
}
