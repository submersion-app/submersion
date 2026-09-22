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
/// A candidate passes by *calling* `ImportSiteLocation`, or by appearing in
/// `allowed` with the reason it does not need to.
///
/// What this proves and what it does not: matching a call rather than the
/// bare name stops a mention in a comment or an unused import from passing
/// the file. It does not tie each individual assignment to a validated
/// value, so a file that already calls the contract could still gain a
/// second, unchecked latitude write. Proving that needs dataflow over the
/// right-hand side of every assignment, which is a job for a linter and not
/// for a regex; the per-importer tests are what cover the behaviour itself.
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
    // Reads a dive's entry or exit fix back out of Submersion's own UDDF
    // export, and already rejects a half pair, a non-finite value and an
    // off-globe pair. It deliberately keeps 0/0, which the contract treats
    // as "no fix": a coordinate this app wrote is one the diver had, and a
    // round trip must not quietly drop it. The `<divecenter>` address it
    // also parses is not a dive site either.
    'lib/core/services/export/uddf/uddf_import_parsers.dart':
        "round-trips a dive's own fix and a dive centre address, not a site",
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

  /// A call into the contract, such as `ImportSiteLocation.named(`. The bare
  /// class name is not enough: a doc comment mentioning it would pass.
  final callsContract = RegExp(r'ImportSiteLocation\s*\.\s*\w+\s*\(');

  /// The contract itself declares the class rather than calling it.
  const contractPath =
      'lib/features/universal_import/data/services/import_site_location.dart';

  /// `Directory.listSync` yields platform paths, so on Windows every
  /// allowlist key and [contractPath] below would miss and the scan would
  /// report phantom violations. `preference_aware_date_format_test.dart`
  /// normalises for the same reason.
  String repoPath(File file) => file.path.replaceAll('\\', '/');

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

        final path = repoPath(file);
        candidates.add(path);
        if (path == contractPath) continue;
        if (allowed.containsKey(path)) continue;
        if (callsContract.hasMatch(source)) continue;
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

  test('a Windows path is normalised before it is compared', () {
    // The allowlist and contractPath are written with forward slashes. This
    // runs on a POSIX machine in CI, so without an explicit check the
    // Windows behaviour would never be exercised anywhere.
    const windowsPath =
        'lib\\features\\universal_import\\data\\services'
        '\\import_site_location.dart';

    expect(repoPath(File(windowsPath)), contractPath);
  });

  test('every allowlisted file still needs its exemption', () {
    for (final MapEntry(key: path, value: reason) in allowed.entries) {
      final file = File(path);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'allowed entry "$path" ($reason) no longer exists; remove it',
      );

      final source = file.readAsStringSync();
      expect(
        writesLatitude.hasMatch(source),
        isTrue,
        reason:
            'allowed entry "$path" ($reason) no longer writes a latitude; '
            'remove it so the list stays honest',
      );
      // A file that now calls the contract would pass on its own merits, so
      // keeping it listed would hide a later regression behind an exemption
      // it no longer needs.
      expect(
        callsContract.hasMatch(source),
        isFalse,
        reason:
            'allowed entry "$path" ($reason) now calls ImportSiteLocation; '
            'remove the exemption and let the scan check it',
      );
    }
  });
}
