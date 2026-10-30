import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

String manifestJson({
  required List<int> schemas,
  String url = 'https://example.com/demo.zip',
}) => jsonEncode({
  'formatVersion': 1,
  'packages': [
    for (final s in schemas)
      {
        'schemaVersion': s,
        'url': url,
        'sha256': 'a' * 64,
        'size': 1000,
        'generatedAt': '2026-10-20T00:00:00.000Z',
      },
  ],
});

void main() {
  test('bestFor picks the newest schema not above the app', () {
    final m = DemoManifest.tryParse(manifestJson(schemas: [300, 318, 320]))!;

    expect(m.bestFor(318)!.schemaVersion, 318);
    expect(m.bestFor(310)!.schemaVersion, 300);
    expect(m.bestFor(299), isNull);
  });

  test(
    'tryParse returns null for malformed JSON, a wrong formatVersion, or a bad entry',
    () {
      expect(DemoManifest.tryParse('{'), isNull);
      expect(
        DemoManifest.tryParse('{"formatVersion": 2, "packages": []}'),
        isNull,
      );
      expect(
        DemoManifest.tryParse(
          '{"formatVersion": 1, "packages": [{"schemaVersion": "x"}]}',
        ),
        isNull,
      );
      expect(DemoManifest.tryParse('[]'), isNull);
    },
  );

  test('tryParse rejects a package url that is not https', () {
    expect(
      DemoManifest.tryParse(
        manifestJson(schemas: [318], url: 'http://x/y.zip'),
      ),
      isNull,
    );
  });

  test('tryParse rejects a sha256 that is not 64 lowercase hex chars', () {
    final bad = jsonDecode(manifestJson(schemas: [318])) as Map;
    (bad['packages'] as List).first['sha256'] = 'XYZ';

    expect(DemoManifest.tryParse(jsonEncode(bad)), isNull);
  });

  test('a package round-trips through JSON', () {
    final p = DemoManifest.tryParse(
      manifestJson(schemas: [318]),
    )!.packages.single;

    expect(DemoPackage.fromJson(p.toJson()), p);
  });

  test('DemoModeSealedException carries its feature', () {
    const e = DemoModeSealedException(DemoSealedFeature.backup);

    expect(e.feature, DemoSealedFeature.backup);
    expect(e.toString(), contains('backup'));
  });
}
