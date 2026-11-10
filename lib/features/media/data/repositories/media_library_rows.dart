import 'package:drift/drift.dart';

import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

/// Which `media` rows are library rows at all, before any facet narrows
/// them: the photo and video gallery, less gear photos unless the Attached
/// to facet asks for them.
class MediaLibraryRows {
  const MediaLibraryRows(this._db);

  final AppDatabase _db;

  /// The library is the photo and video gallery. Signatures never appear,
  /// in any spelling, and neither do documents (#3052): invoices and
  /// briefings attached through a dive's, site's or equipment's Documents
  /// section belong to that section, and an equipment-only document showed
  /// up in the grid as "Unlinked".
  ///
  /// An exclusion list rather than `IN ('photo', 'video')`: parseMediaType
  /// reads any file_type it does not recognise as a photo, and a whitelist
  /// would hide those rows here while every other surface shows them.
  static final List<String> nonGalleryFileTypes = [
    ...kSignatureFileTypes,
    mediaTypeToDbString(MediaType.document),
  ];

  /// A row of the ordinary library views: no signature or document, and no
  /// gear photo.
  Expression<bool> get galleryRow => _galleryFileType & _gearOnly.not();

  /// The library rows [filter] may show to [diverId]. Gear photos show only
  /// when the Attached to facet asks for Equipment (issue #4224), which then
  /// narrows the rows to the kinds picked. Their rows carry no dive, so the
  /// library's dive-based diver scope passes them all; the gear's own
  /// visibility (issue #2046) decides instead, as in the Equipment gallery.
  Expression<bool> forFilter(MediaLibraryFilter filter, String? diverId) {
    if (!filter.attachedTo.contains(MediaAttachmentKind.equipment)) {
      return galleryRow;
    }
    final visibleGear = VisibilityFilter.visibleEquipmentIds(
      _db,
      _db.media.equipmentId,
      diverId,
    );
    return _galleryFileType & (_gearOnly.not() | visibleGear);
  }

  Expression<bool> get _galleryFileType =>
      _db.media.fileType.isNotIn(nonGalleryFileTypes);

  /// A gear photo (issue #3355): a row linked to a piece of gear and to no
  /// dive or site. It lives in the Equipment gallery and stays out of the
  /// ordinary library views. A row a dive or site also holds is that dive's
  /// or site's photo as well, so it is not one.
  Expression<bool> get _gearOnly {
    final m = _db.media;
    return m.equipmentId.isNotNull() & m.diveId.isNull() & m.siteId.isNull();
  }
}
