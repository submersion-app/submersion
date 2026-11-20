import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/engines/onnx/onnx_runtime_attribution.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(LicenseRegistry.reset);
  tearDown(LicenseRegistry.reset);

  test(
    'carries ONNX Runtime\'s licence and its notices where it ships',
    () async {
      // The app ships ONNX Runtime (MIT) on Android, Windows and Linux, with
      // the libraries it is built from; their notices must travel with it.
      OnnxRuntimeAttribution.registerLicense(platform: TargetPlatform.android);
      final entries = await LicenseRegistry.licenses.toList();
      final text = entries
          .where((e) => e.packages.contains(OnnxRuntimeAttribution.packageName))
          .expand((e) => e.paragraphs)
          .map((p) => p.text)
          .join(' ');

      expect(text, contains('MIT License'));
      expect(text, contains('Microsoft Corporation'));
      expect(text, contains('THIRD PARTY SOFTWARE NOTICES'));
    },
  );

  test('registers nothing on Apple platforms, which use Core ML', () async {
    OnnxRuntimeAttribution.registerLicense(platform: TargetPlatform.iOS);
    OnnxRuntimeAttribution.registerLicense(platform: TargetPlatform.macOS);
    final entries = await LicenseRegistry.licenses.toList();
    expect(
      entries.where(
        (e) => e.packages.contains(OnnxRuntimeAttribution.packageName),
      ),
      isEmpty,
    );
  });
}
