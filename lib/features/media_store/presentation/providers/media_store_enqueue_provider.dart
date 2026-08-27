import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// Bridge consumed by MediaImportService construction. Delegates to the
/// runtime-aware implementation; with no store attached it is a no-op.
/// Kept as a separate library so import-heavy provider files depend on a
/// single tiny symbol.
final mediaStoreEnqueueProvider = Provider<void Function(String mediaId)>(
  (ref) => ref.watch(mediaStoreEnqueueImplProvider),
);
