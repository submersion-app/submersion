import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';

/// Per-item media families must auto-dispose (#1175).
///
/// Riverpod 3 defaults `isAutoDispose` to FALSE for every provider type
/// (riverpod 3.4.2, e.g. `providers/future_provider.dart:107` and
/// `providers/stream_provider.dart:96`). That is the opposite of Riverpod 2's
/// familiar `.autoDispose` opt-in, and it is easy to carry the old intuition
/// across. For a `.family` keyed per media item the consequence is not a
/// missed optimisation, it is an unbounded leak: one entry survives per key
/// for the process lifetime.
///
/// For the byte families that entry is a full-resolution image buffer,
/// megabytes each, so a browsing session accumulated every photo it had shown
/// until Android killed the app. For [mediaQueueFactsProvider] it is a live
/// Drift watch on `media_transfer_queue`, and Drift re-runs every registered
/// watch query on every write to that table -- so an upload drain cost one
/// query per row the grid had ever rendered, per row it stamped.
///
/// Retention is handled separately by `retainFor`, which holds a value for a
/// bounded window so swipe-back still hits the cache. That is a window, not
/// permanence, and it only works on a provider that auto-disposes at all.
///
/// Asserted through `dynamic` because the flag's declaring type,
/// `ProviderOrFamily`, is not exported by `package:riverpod` or
/// `package:flutter_riverpod` -- it lives in `src/core/foundation.dart` and
/// `riverpod.dart`'s `show` clause omits it. `isAutoDispose` itself is a
/// public field on it, so the read is stable; only the type name is
/// unreachable. Importing the src path would trip `implementation_imports`.
void main() {
  final mustAutoDispose = <String, dynamic>{
    'mediaBytesProvider': mediaBytesProvider,
    'resolvedThumbnailProvider': resolvedThumbnailProvider,
    'resolvedFullResolutionProvider': resolvedFullResolutionProvider,
    'assetThumbnailProvider': assetThumbnailProvider,
    'assetFullResolutionProvider': assetFullResolutionProvider,
    'mediaQueueFactsProvider': mediaQueueFactsProvider,
    'mediaProvenanceProvider': mediaProvenanceProvider,
  };

  for (final entry in mustAutoDispose.entries) {
    test('${entry.key} auto-disposes', () {
      expect(
        entry.value.isAutoDispose,
        isTrue,
        reason:
            '${entry.key} is keyed per media item and holds either image bytes '
            'or a live database subscription. Riverpod 3 keeps a family entry '
            'forever unless the provider passes isAutoDispose: true, so '
            'without it this grows without bound for the whole process.',
      );
    });
  }
}
