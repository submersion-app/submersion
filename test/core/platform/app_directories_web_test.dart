import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/app_directories_web.dart';

/// The browser variant of the directories facade, imported directly.
void main() {
  test('web directories are fixed names under the OPFS root', () async {
    expect(await AppDirectories.support(), '/opfs/support');
    expect(await AppDirectories.documents(), '/opfs/documents');
    expect(await AppDirectories.temp(), '/opfs/temp');
  });
}
