import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Install [fake] as the path provider until the current test ends.
///
/// Call it from `setUp` or from a test body. The previous provider comes back
/// when the test ends, pass or fail, so a fake cannot outlive the temporary
/// directory it points into and reach the next test file in the same isolate
/// (issue #2500).
void useFakePathProvider(PathProviderPlatform fake) {
  final original = PathProviderPlatform.instance;
  PathProviderPlatform.instance = fake;
  addTearDown(() => PathProviderPlatform.instance = original);
}
