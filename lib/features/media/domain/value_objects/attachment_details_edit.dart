import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';

/// One field of an [AttachmentDetailsEdit]: write [value], which may itself
/// be null to clear the field.
final class FieldChange<T> {
  const FieldChange(this.value);

  final T value;
}

/// The fields an Edit details save changes (issue #1039). A null member is
/// left untouched, so a save writes only what the diver changed.
///
/// There is deliberately no name: the stored filename is how other devices
/// re-find a photo and how the repair wizard finds a moved file, so it is
/// never edited.
class AttachmentDetailsEdit {
  const AttachmentDetailsEdit({this.category, this.displaySize});

  final FieldChange<SiteAttachmentCategory?>? category;
  final FieldChange<AttachmentDisplaySize?>? displaySize;

  bool get isEmpty => category == null && displaySize == null;

  /// [item] with this edit applied, for showing the saved state before the
  /// list reloads.
  MediaItem applyTo(MediaItem item) => item.copyWith(
    siteCategory: category == null ? item.siteCategory : category!.value,
    displaySizeOverride: displaySize == null
        ? item.displaySizeOverride
        : displaySize!.value,
  );
}

/// The edit that takes [item] to the sheet's current values.
AttachmentDetailsEdit diffAttachmentDetails(
  MediaItem item, {
  required SiteAttachmentCategory? category,
  required AttachmentDisplaySize? displaySize,
}) => AttachmentDetailsEdit(
  category: category == item.siteCategory ? null : FieldChange(category),
  displaySize: displaySize == item.displaySizeOverride
      ? null
      : FieldChange(displaySize),
);
