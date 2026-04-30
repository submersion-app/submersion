// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3a.md`
// Task 16. Locks the constant values for the network media cache caps so
// that future Phase 3c work surfacing these as Settings has a known
// baseline to migrate from.

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/network_cache_config.dart';

void main() {
  group('network_cache_config defaults', () {
    test('disk cap is 500 MB', () {
      expect(kDiskCacheCapBytes, 500 * 1024 * 1024);
    });

    test('memory cap is 75 MB', () {
      expect(kMemoryCacheCapBytes, 75 * 1024 * 1024);
    });
  });
}
