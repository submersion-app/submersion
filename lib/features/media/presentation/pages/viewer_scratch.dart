import 'package:flutter/widgets.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';

/// The species the diver tagged on each file not kept yet, by its scratch
/// id (issue #5122).
typedef ScratchTags = Map<String, List<SpeciesTagChip>>;

/// What the media viewer needs to show files the diver has not kept (issue
/// #5122): the Identify viewer.
///
/// In this mode the viewer reads each item from the list it was given (no
/// file is a row), shows no dive, site or edit actions, and holds the
/// species tagged on each file in a sitting of its own, which is never
/// saved: [onKeep] reads it.
class ViewerScratch {
  const ViewerScratch({required this.onKeep});

  /// Keeps [current], or every file not kept yet, as the diver chooses on
  /// the Keep sheet, with [tags]. Returns the scratch ids kept.
  final Future<Set<String>> Function(
    BuildContext context,
    MediaItem current,
    ScratchTags tags,
  )
  onKeep;
}
