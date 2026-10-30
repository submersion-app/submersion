import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

/// How many photos and videos the library holds, for step 4 of Set up this
/// device (issue #3482): what a first store would keep copies of.
final setUpPhotoCountProvider = FutureProvider.autoDispose<int>((ref) {
  final media = ref.watch(mediaRepositoryProvider);
  ref.invalidateSelfWhen(media.watchMediaChanges());
  return media.countPhotosAndVideos();
});
