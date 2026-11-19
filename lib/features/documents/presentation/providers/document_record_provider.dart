import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/documents/data/services/document_edit_save_service.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';

/// Document [id] as a page's sitting edits it (issue #4527, phase 3): its
/// row, its pages without their content, and its tags; refreshed when any
/// of them changes.
final documentRecordProvider = FutureProvider.family<DocumentRecord?, String>((
  ref,
  id,
) async {
  final service = ref.watch(documentEditSaveServiceProvider);
  ref.invalidateSelfWhen(service.watchChanges());
  ref.invalidateSelfWhen(service.watchTagChanges());
  return service.read(id);
});
