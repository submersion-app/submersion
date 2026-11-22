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

  Future<String> textOf(String package) async {
    final entries = await LicenseRegistry.licenses.toList();
    return entries
        .where((e) => e.packages.contains(package))
        .expand((e) => e.paragraphs)
        .map((p) => p.text)
        .join(' ');
  }

  test("on Windows it also carries Microsoft's Windows ML terms", () async {
    // Windows ships Windows ML's files, whose terms the app's users agree
    // to (the installer shows them too).
    OnnxRuntimeAttribution.registerLicense(platform: TargetPlatform.windows);
    final text = await textOf(OnnxRuntimeAttribution.windowsMlPackageName);

    expect(text, contains('MICROSOFT SOFTWARE LICENSE TERMS'));
    expect(text, contains('Microsoft Windows ML Runtime'));
  });

  test('Android and Linux carry no Windows ML terms', () async {
    OnnxRuntimeAttribution.registerLicense(platform: TargetPlatform.android);
    OnnxRuntimeAttribution.registerLicense(platform: TargetPlatform.linux);

    expect(await textOf(OnnxRuntimeAttribution.windowsMlPackageName), isEmpty);
  });

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
