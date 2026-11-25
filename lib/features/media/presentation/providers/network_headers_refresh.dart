import 'package:flutter/foundation.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';

/// Lets a view that resolved a network image hear when the headers it was
/// given may have gone stale.
extension NetworkHeadersRefresh on WidgetRef {
  /// Calls [resolveAgain] when [networkHeadersEpochProvider] moves (a saved
  /// secret changed, or a share's session was replaced) and [item] is served
  /// over the network. A resolution keeps the headers it was handed, so a
  /// tile on screen would otherwise keep sending a dead session cookie and
  /// stay broken until it is rebuilt. Call from `build`.
  void resolveAgainWhenHeadersStale(MediaItem item, VoidCallback resolveAgain) {
    listen<int>(networkHeadersEpochProvider, (_, _) {
      if (item.sourceType == MediaSourceType.networkUrl ||
          item.sourceType == MediaSourceType.manifestEntry) {
        resolveAgain();
      }
    });
  }
}
