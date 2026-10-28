// A flutter test run as a tool (scripts/demo_data/pack.sh), outside test/.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';

import 'src/harvest/harvester.dart';
import 'src/packaging/demo_builder.dart';
import 'src/seeders/seed_context.dart';

/// Step 2 of the demo logbook (issue #3708), run by scripts/demo_data/pack.sh:
/// builds the logbook from harvested shapes, checks it, and packages it.
///
///   DEMO_PACK_SHAPES  the harvest folder (shapes, source string hashes, salt)
///   DEMO_PACK_PHOTOS  a folder of photos with credits.json
///   DEMO_PACK_OUT     where the zip, manifest entry and manifest go
///   DEMO_PACK_SEED    optional, default 1
///   DEMO_PACK_ANCHOR  optional build date (yyyy-mm-dd), default today
void main() {
  // The species catalogue loads from the app's bundled assets.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('build the demo logbook', () async {
    final env = Platform.environment;
    final shapesDir = env['DEMO_PACK_SHAPES'];
    final photosDir = env['DEMO_PACK_PHOTOS'];
    final out = env['DEMO_PACK_OUT'];
    expect(shapesDir, isNotNull, reason: 'DEMO_PACK_SHAPES');
    expect(photosDir, isNotNull, reason: 'DEMO_PACK_PHOTOS');
    expect(out, isNotNull, reason: 'DEMO_PACK_OUT');

    // The app's background work would race the seeding; the build runs the
    // same services itself, in order.
    QualityScanScheduler.enabled = false;
    SensorSummaryScheduler.enabled = false;
    DerivedMetricsScheduler.enabled = false;
    SharedPreferences.setMockInitialValues({});

    final credits =
        (jsonDecode(File(p.join(photosDir!, 'credits.json')).readAsStringSync())
                as List)
            .cast<Map<String, Object?>>();
    final photos = [
      for (final c in credits)
        DemoPhoto(
          fileName: c['fileName']! as String,
          credit: c['credit']! as String,
          subject: c['subject']! as String,
        ),
    ];
    final hashes = File(
      p.join(shapesDir!, 'source_strings.txt'),
    ).readAsLinesSync().where((l) => l.isNotEmpty).toSet();
    final salt = File(p.join(shapesDir, 'salt.txt')).readAsStringSync().trim();
    final anchor = env['DEMO_PACK_ANCHOR'] == null
        ? DateTime.now()
        : DateTime.parse(env['DEMO_PACK_ANCHOR']!);

    final result = await DemoBuilder().build(
      shapes: await HarvestWriter.readShapes(shapesDir),
      photosDir: photosDir,
      photos: photos,
      seed: int.parse(env['DEMO_PACK_SEED'] ?? '1'),
      anchor: DateTime(anchor.year, anchor.month, anchor.day),
      outDir: out!,
      sourceStringHashes: hashes,
      salt: salt,
    );

    final manifest = File(p.join(out, 'demo-manifest.json'));
    manifest.writeAsStringSync(
      DemoBuilder.mergeManifest(
        existing: manifest.existsSync() ? manifest.readAsStringSync() : null,
        entry: File(p.join(out, 'manifest-entry.json')).readAsStringSync(),
      ),
    );
    // ignore: avoid_print
    print(
      'built ${result.zip.path}: ${result.package.size} bytes, '
      'sha256 ${result.package.sha256}',
    );
  }, timeout: const Timeout(Duration(minutes: 30)));
}
