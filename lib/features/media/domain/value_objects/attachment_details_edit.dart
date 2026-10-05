import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_filename.dart';

/// One field of an [AttachmentDetailsEdit]: write [value], which may itself
/// be null to clear the field.
final class FieldChange<T> {
  const FieldChange(this.value);

  final T value;
}

/// The fields an Edit details save changes (issue #1039). A null member is
/// left untouched, so a save writes only what the diver changed.
class AttachmentDetailsEdit {
  const AttachmentDetailsEdit({this.filename, this.category, this.displaySize});

  final FieldChange<String?>? filename;
  final FieldChange<SiteAttachmentCategory?>? category;
  final FieldChange<AttachmentDisplaySize?>? displaySize;

  bool get isEmpty =>
      filename == null && category == null && displaySize == null;

  /// [item] with this edit applied, for showing the saved state before the
  /// list reloads.
  MediaItem applyTo(MediaItem item) => item.copyWith(
    originalFilename: filename == null
        ? item.originalFilename
        : filename!.value,
    siteCategory: category == null ? item.siteCategory : category!.value,
    displaySizeOverride: displaySize == null
        ? item.displaySizeOverride
        : displaySize!.value,
  );
}

bool _hasName(MediaItem item) =>
    (item.originalFilename ?? '').trim().isNotEmpty;

/// Why [stem] cannot be saved as [item]'s new name, or null when it can.
///
/// A blank field is fine for an item that never had a name (some gallery
/// rows store none): it simply stays unnamed, so the diver can still
/// categorize it.
AttachmentNameError? attachmentNameError(MediaItem item, String stem) {
  if (!_hasName(item) && stem.trim().isEmpty) return null;
  return AttachmentFilename.validate(stem);
}

/// The edit that takes [item] to the sheet's current values.
AttachmentDetailsEdit diffAttachmentDetails(
  MediaItem item, {
  required String stem,
  required SiteAttachmentCategory? category,
  required AttachmentDisplaySize? displaySize,
}) {
  FieldChange<String?>? filename;
  if (_hasName(item) || stem.trim().isNotEmpty) {
    final composed = AttachmentFilename.split(
      item.originalFilename,
    ).compose(stem);
    if (composed != item.originalFilename) filename = FieldChange(composed);
  }
  return AttachmentDetailsEdit(
    filename: filename,
    category: category == item.siteCategory ? null : FieldChange(category),
    displaySize: displaySize == item.displaySizeOverride
        ? null
        : FieldChange(displaySize),
  );
}
