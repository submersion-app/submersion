import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A key written twice in one ARB file is invalid JSON, and nothing else
/// catches it: `jsonDecode` keeps the last occurrence, so gen-l10n succeeds,
/// the generated catalog looks right and the key-set parity test compares
/// sets. Whichever copy loses is invisible until someone edits the file and
/// the wrong one survives. Merges are how they arrive: a conflict around a
/// block of keys can leave both sides' copy of the same key.
///
/// The scan is line-based because a parsed map has already lost the
/// duplicate. Every top-level key in these files sits at exactly two spaces
/// of indentation, which the count check below pins down.
void main() {
  final files =
      Directory('lib/l10n/arb')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final topLevelKey = RegExp(r'^  "([^"]+)"\s*:', multiLine: true);

  test('the catalogs are found', () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last;

    test('$name declares every key once', () {
      final text = file.readAsStringSync();
      final counts = <String, int>{};
      for (final match in topLevelKey.allMatches(text)) {
        final key = match.group(1)!;
        counts[key] = (counts[key] ?? 0) + 1;
      }
      final duplicated = [
        for (final entry in counts.entries)
          if (entry.value > 1) '${entry.key} (${entry.value}x)',
      ]..sort();

      expect(
        duplicated,
        isEmpty,
        reason:
            'Duplicate keys in $name. jsonDecode keeps the last one, so the '
            'earlier value is silently dropped: delete the stale copy.',
      );

      // The regex must see exactly the top-level keys, or a duplicate could
      // hide below the indentation it scans.
      final parsed = jsonDecode(text) as Map<String, dynamic>;
      expect(counts.length, parsed.length, reason: 'scan missed keys in $name');
    });
  }
}
