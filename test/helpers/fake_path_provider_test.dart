import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'fake_path_provider.dart';

class _Fake extends PathProviderPlatform {}

void main() {
  final original = PathProviderPlatform.instance;
  final fake = _Fake();

  group('installed from setUp', () {
    setUp(() => useFakePathProvider(fake));

    test('the fake answers during the test', () {
      expect(PathProviderPlatform.instance, same(fake));
    });
  });

  test('the previous provider is back once that test ends', () {
    expect(PathProviderPlatform.instance, same(original));
  });

  test('installed from a test body, it is gone after the test', () {
    useFakePathProvider(fake);

    expect(PathProviderPlatform.instance, same(fake));
  });

  test('and the next test starts from the previous provider', () {
    expect(PathProviderPlatform.instance, same(original));
  });
}
