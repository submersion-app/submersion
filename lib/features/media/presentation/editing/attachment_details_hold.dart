import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Holds a site attachment's chosen [category] and display [size] in
/// [sitting], the attachment's own sitting (issue #4527), until its Save:
/// from the photo viewer, the PDF viewer and the details page alike. A
/// sitting that has ended, or is being saved, takes nothing.
void holdAttachmentDetails(
  EditSession<PhotoRecord>? sitting,
  SiteAttachmentCategory? category,
  AttachmentDisplaySize? size,
) {
  if (sitting == null || sitting.isDisposed || sitting.isFrozen) return;
  sitting
    ..set(photoSiteCategoryField, category)
    ..set(photoDisplaySizeField, size);
}
