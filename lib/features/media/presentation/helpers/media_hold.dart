import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// What a picker hands a sitting on a dive in place of writing (issue
/// #4527, plan 6): the rows it would write, shown as tiles until Save.
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
