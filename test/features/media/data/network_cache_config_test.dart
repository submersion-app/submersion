// Locks the values of the caps this app actually applies. There is no disk
// cap asserted here on purpose: the former kDiskCacheCapBytes was wired to
// nothing, so its test only proved the constant equalled itself. See #1375.

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/network_cache_config.dart';

void main() {
  group('network_cache_config defaults', () {
    test('memory cap is 75 MB', () {
      expect(kMemoryCacheCapBytes, 75 * 1024 * 1024);
    });

    test('memory object cap is 200', () {
      expect(kMemoryCacheCapObjects, 200);
    });
  });
}
