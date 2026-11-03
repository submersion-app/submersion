import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/media/presentation/widgets/media_console_scaffold.dart';

/// A browser can neither watch folders nor import files (issue #4121), so
/// the Media console shows only the library and the transfers there.
void main() {
  test('natively every section is offered', () {
    expect(
      mediaConsoleSectionsFor(currentDeviceCapabilities()),
      MediaConsoleSection.values,
    );
  });

  test('a browser offers the library and the transfers only', () {
    expect(mediaConsoleSectionsFor(DeviceCapabilities.web), [
      MediaConsoleSection.library,
      MediaConsoleSection.transfers,
    ]);
  });
}
