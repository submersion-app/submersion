import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/photo_access_actions.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';

/// The system hand-offs for a photo outside a limited selection.
final photoAccessActionsProvider = Provider<PhotoAccessActions>(
  (ref) => const PhotoManagerAccessActions(),
);

/// Whether this device's photo access is a limited selection, read without
/// prompting (media sync program spec 6.3). False where there is no photo
/// library, and when the platform cannot say: the actions it gates are an
/// offer, never a verdict.
// no-tick: reads the platform's permission state, not a table. Callers
// invalidate it after sending the user to change that state.
final galleryAccessLimitedProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final photos = ref.watch(photoPickerServiceProvider);
  if (!photos.supportsGalleryBrowsing) return false;
  try {
    return await photos.currentPermission() == PhotoPermissionStatus.limited;
  } on Object {
    return false;
  }
});
