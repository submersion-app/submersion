import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every importer that builds a location must go through `ImportSiteLocation`.
///
/// Five importers each decided, independently, that a site was worth keeping
/// only if it had a name, and each put that check ahead of the line that read
/// the coordinates (#2209, #2210, #2211, #2212, #2213). The fixes were one
/// fix five times over, so #2232 put the rules in one place. This scan is the
/// ratchet: a sixth importer that writes coordinates has to reach for the
/// shared contract, or fail here.
///
/// A file is a candidate when it assigns a `latitude` key into a map, which
/// is how every import layer in this repo hands a position to the next one.
/// A candidate passes by naming [ImportSiteLocation], or by appearing in
/// [allowed] with the reason it does not need to.
void main() {
  /// Where import-side coordinates are produced. Export builders are not
  /// scanned: they read a `DiveSite` that already has a name.
  const scannedRoots = [
    'lib/features/universal_import/data',
    'lib/features/dive_import/data',
    'lib/core/services/export/uddf',
  ];

  /// Files that write a latitude for something that is not a dive site, each
  /// with the reason the contract does not apply.
  const allowed = <String, String>{
    // The dive's own entry and exit fixes, which is the contract's other
    // half: a parser with nowhere to put a site writes the pair onto the
    // dive, and `UddfEntityImporter` reads it into `Dive.entryLocation`.
    'lib/features/universal_import/data/parsers/fit_import_parser.dart':
        "the dive's own fix, not a site",
    'lib/features/universal_import/data/csv/extractors/dive_extractor.dart':
        "the dive's own fix, not a site",
    'lib/core/services/export/uddf/uddf_import_parsers.dart':
        "a dive's own fix and a dive center's address, not a site",
    // A photo's coordinates, which belong to the picture rather than to the
    // place the dive happened.
    'lib/features/universal_import/data/services/macdive_media_entries.dart':
        "a photo's coordinates, not a site",
    // Returns the unnamed map deliberately: `foldSubsurfaceSites` is the
    // caller, and naming from coordinates happens there, once, after the
    // fold has had its chance to merge the entry into a named neighbour.
    'lib/features/universal_import/data/parsers/subsurface/subsurface_inline_site.dart':
        'hands its unnamed map to foldSubsurfaceSites, which names it',
  };

  /// Assignment of a `latitude` key into a map, in either of the two shapes
  /// this repo writes: `map['latitude'] = x` and `'latitude': x`.
  final writesLatitude = RegExp(
    '''\\[['"]latitude['"]\\]\\s*=|['"]latitude['"]\\s*:''',
  );

  List<File> dartFilesUnder(String root) => Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('every import-side latitude writer goes through the contract', () {
    final offenders = <String>[];
    final candidates = <String>[];

    for (final root in scannedRoots) {
      for (final file in dartFilesUnder(root)) {
        final source = file.readAsStringSync();
        if (!writesLatitude.hasMatch(source)) continue;

        final path = file.path;
        candidates.add(path);
        if (allowed.containsKey(path)) continue;
        if (source.contains('ImportSiteLocation')) continue;
        offenders.add(path);
      }
    }

    // A rule that matches nothing guards nothing: if a refactor moves these
    // files, the scan must fail loudly rather than pass empty.
    expect(
      candidates,
      isNotEmpty,
      reason: 'the scan found no latitude writers at all; check scannedRoots',
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'These files write a latitude without going through '
          'ImportSiteLocation. A site must never be dropped for want of a '
          'name: call ImportSiteLocation.named to name it from its '
          'coordinates, or add the file to `allowed` with the reason the '
          'contract does not apply to it.\n  ${offenders.join('\n  ')}',
    );
  });

  test('every allowlisted file still exists and still writes a latitude', () {
    for (final MapEntry(key: path, value: reason) in allowed.entries) {
      final file = File(path);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'allowed entry "$path" ($reason) no longer exists; remove it',
      );
      expect(
        writesLatitude.hasMatch(file.readAsStringSync()),
        isTrue,
        reason:
            'allowed entry "$path" ($reason) no longer writes a latitude; '
            'remove it so the list stays honest',
      );
    }
  });
}
