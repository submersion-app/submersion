import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridge consumed by MediaImportService construction. Overridden in
/// media_store_providers.dart once a store runtime exists; the default
/// no-op keeps import flows working with no store configured.
final mediaStoreEnqueueProvider = Provider<void Function(String mediaId)>(
  (ref) => (_) {},
);
