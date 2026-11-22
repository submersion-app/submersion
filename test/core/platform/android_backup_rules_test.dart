import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The marine life model pack (about 800 MB, downloadable again) must stay
/// out of Android's Auto Backup, whose 25 MB limit it would exceed, skipping
/// the diver's whole backup; everything else is backed up as before
/// (piece 3 of marine life identification, section 2).
void main() {
  final res = p.join('android', 'app', 'src', 'main', 'res', 'xml');
  final exclude = RegExp(
    r'<exclude\s+domain="file"\s+path="species_id/pack/"\s*/>',
  );

  test('Android 11 and earlier leave out only the model pack', () {
    final rules = File(p.join(res, 'backup_rules.xml')).readAsStringSync();
    expect(exclude.allMatches(rules), hasLength(1));
    expect(rules, isNot(contains('<include')));
    expect(RegExp('<exclude').allMatches(rules), hasLength(1));
  });

  test('Android 12 and later leave it out of backups and transfers', () {
    final rules = File(
      p.join(res, 'data_extraction_rules.xml'),
    ).readAsStringSync();
    expect(exclude.allMatches(rules), hasLength(2));
    expect(rules, contains('<cloud-backup>'));
    expect(rules, contains('<device-transfer>'));
    expect(rules, isNot(contains('<include')));
    expect(RegExp('<exclude').allMatches(rules), hasLength(2));
  });

  test('the manifest names both rule files', () {
    final manifest = File(
      p.join('android', 'app', 'src', 'main', 'AndroidManifest.xml'),
    ).readAsStringSync();
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });
}
