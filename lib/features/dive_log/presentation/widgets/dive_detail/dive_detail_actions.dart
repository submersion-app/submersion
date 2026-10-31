import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// What the sections ask the page to do on their behalf.
///
/// These run on the page rather than on the section that offers them: each
/// outlives the tap by dialogs and imports, and a section can leave the tree
/// in the meantime (a pair stacking in a resized window remounts its cards),
/// while the page is still there to report the result.
class DiveDetailActions {
  const DiveDetailActions({
    required this.setPrimarySource,
    required this.splitSource,
    required this.separateSegments,
    required this.scanGallery,
    required this.addPhotos,
    required this.addDocument,
    required this.openDocument,
  });

  final void Function(String readingId) setPrimarySource;
  final void Function(Dive dive, String sourceId) splitSource;
  final void Function(Dive dive, int segmentCount) separateSegments;
  final void Function(Dive dive) scanGallery;
  final void Function(Dive dive) addPhotos;
  final void Function(Dive dive) addDocument;
  final void Function(MediaItem item) openDocument;
}
