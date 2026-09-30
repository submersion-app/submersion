import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/explore/presentation/explore_label_lookup.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Explore's field labels are ARB keys (#2641); these pin that the generated
/// lookup covers every one of them and hands anything else to the query one.
void main() {
  final en = l10nForLocaleTag('en');

  test('every plain explore field and chip key resolves through it', () {
    final arb =
        jsonDecode(File('lib/l10n/arb/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    // Keys with placeholders generate methods, not getters, and are not in
    // the lookup.
    final keys = arb.entries
        .where(
          (e) =>
              (e.key.startsWith('explore_field_') ||
                  e.key.startsWith('explore_chip_')) &&
              e.value is String &&
              !(e.value as String).contains('{'),
        )
        .map((e) => e.key);
    expect(keys, isNotEmpty);
    for (final key in keys) {
      expect(
        exploreLabelForKey(en, key),
        isNot(key),
        reason:
            '$key is missing from explore_label_lookup.dart; '
            'run python3 scripts/gen_query_label_lookup.py',
      );
    }
  });

  test('a registry key resolves through the query lookup', () {
    expect(exploreLabelForKey(en, 'query_dives_sac'), en.query_dives_sac);
  });

  test('an unknown key returns itself', () {
    expect(
      exploreLabelForKey(en, 'explore_no_such_key'),
      'explore_no_such_key',
    );
  });
}
