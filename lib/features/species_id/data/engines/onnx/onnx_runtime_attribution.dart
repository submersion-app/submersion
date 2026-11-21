import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Credit for ONNX Runtime, which the app ships on Android, Windows and
/// Linux for marine life identification: its MIT licence, and the notices
/// of the libraries it is built from, which travel with the binary.
abstract final class OnnxRuntimeAttribution {
  /// The heading the credit is filed under on the license page.
  static const String packageName = 'ONNX Runtime';

  /// The heading Windows ML's terms are filed under, on Windows.
  static const String windowsMlPackageName = 'Windows ML';

  static const _notices = 'assets/licenses/onnxruntime_third_party_notices.txt';

  /// Microsoft's terms for the Windows ML files the Windows build ships
  /// (Microsoft.Windows.AI.MachineLearning 2.5.96), accepted by the
  /// maintainer on 2026-11-20; the installer shows them as well.
  static const _windowsMlTerms = 'assets/licenses/windows_ml_license.txt';

  static const _licence = '''
MIT License

Copyright (c) Microsoft Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''';

  /// Adds the credit where ONNX Runtime ships ([platform] defaults to the
  /// running one): not on Apple platforms, which use Core ML, nor the web.
  /// On Windows, Windows ML's terms are added too. Called once from
  /// `main()`; the notices are read only when the license page is opened.
  static void registerLicense({TargetPlatform? platform}) {
    final on = platform ?? defaultTargetPlatform;
    if (kIsWeb ||
        !(on == TargetPlatform.android ||
            on == TargetPlatform.windows ||
            on == TargetPlatform.linux)) {
      return;
    }
    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks(<String>[packageName], _licence);
      yield LicenseEntryWithLineBreaks(<String>[
        packageName,
      ], await rootBundle.loadString(_notices));
      if (on == TargetPlatform.windows) {
        yield LicenseEntryWithLineBreaks(<String>[
          windowsMlPackageName,
        ], await rootBundle.loadString(_windowsMlTerms));
      }
    });
  }
}
