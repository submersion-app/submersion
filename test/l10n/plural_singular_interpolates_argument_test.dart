import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Guards French and Portuguese against spelling the pluralised value out as
/// the digit `1` in a plural's singular branch.
///
/// The branch must interpolate the argument it is pluralised on, which is not
/// always named `count`: `{total, plural, =1{{count} sur 1 composant}}` has to
/// become `=1{{count} sur {total} composant}`, not `{count}`.
///
/// Flutter's `gen-l10n` compiles an ARB `=1{...}` branch into the CLDR **`one`
/// plural category**, not an exact-value match. French and Portuguese both put
/// zero in that category (`one: i = 0,1`), so a branch written as
/// `=1{1 plongée}` generates `one: '1 plongée'` and renders a count of zero as
/// "1 plongée". English is unaffected: it puts zero in `other`, which is why an
/// English-only widget test cannot see this. Issue #2176, found through #2084.
///
/// Only `fr` and `pt` are checked. Every other shipped locale excludes zero
/// from its `one` category, and `he` and `ar` use word forms there
/// ("צלילה אחת", "غطسة واحدة") rather than a digit, so interpolating the
/// placeholder would be wrong for them.
void main() {
  const affectedLocales = ['fr', 'pt'];

  group('ARB singular branches interpolate their plural argument', () {
    for (final locale in affectedLocales) {
      test('app_$locale.arb spells no plural argument out as a literal 1', () {
        final arb =
            jsonDecode(File('lib/l10n/arb/app_$locale.arb').readAsStringSync())
                as Map<String, dynamic>;

        final offenders = <String>[];
        arb.forEach((key, value) {
          if (key.startsWith('@') || value is! String) return;
          forEachPluralArgument(value, (argument, branches) {
            for (final selector in const ['=1', 'one']) {
              final branch = branches[selector];
              if (branch == null) continue;
              // A literal `1` is only a bug when it stands in for the value
              // being pluralised. A branch that already interpolates its own
              // argument is using the digit for something else, such as
              // "Étape 1 sur {count}".
              if (containsBareOne(branch) && !branch.contains('{$argument}')) {
                offenders.add('$key [$argument] $selector{$branch}');
              }
            }
          });
        });

        expect(
          offenders,
          isEmpty,
          reason:
              '${offenders.length} singular branch(es) in app_$locale.arb '
              'hardcode the digit 1, so a count of zero renders as "1". '
              'Interpolate the branch\'s own plural argument, which is not '
              'always named count: "=1{1 plongee}" pluralised on count becomes '
              '"=1{{count} plongee}", and "=1{{count} sur 1 composant}" '
              'pluralised on total becomes "=1{{count} sur {total} composant}".'
              '\n'
              '${offenders.take(20).join('\n')}'
              '${offenders.length > 20 ? '\n...and ${offenders.length - 20} more' : ''}',
        );
      });
    }
  });

  group('generated localizations render a zero count as zero', () {
    Future<AppLocalizations> load(String languageCode) =>
        AppLocalizations.delegate.load(Locale(languageCode));

    test('French', () async {
      final l10n = await load('fr');

      expect(l10n.diveSites_list_tile_diveCount(0), '0 plongée');
      expect(l10n.diveSites_list_tile_diveCount(1), '1 plongée');
      expect(l10n.diveSites_list_tile_diveCount(2), '2 plongées');

      // Written with `one{...}` rather than `=1{...}`, same category.
      expect(l10n.forms_section_issues(0), '0 problème');

      // The plural argument is `total`, not `count`.
      expect(l10n.equipment_components_countOfTotal(3, 0), '3 sur 0 composant');

      // Two plural arguments inside one message.
      expect(l10n.media_diveScan_foundPhotos(0), startsWith('0 photo trouvée'));
    });

    test('Portuguese', () async {
      final l10n = await load('pt');

      expect(l10n.diveSites_list_tile_diveCount(0), '0 mergulho');
      expect(l10n.diveSites_list_tile_diveCount(1), '1 mergulho');
      expect(l10n.diveSites_list_tile_diveCount(2), '2 mergulhos');
      expect(l10n.settings_cloudSync_pendingChanges(0), '0 alteracao pendente');
      expect(l10n.equipment_components_countOfTotal(3, 0), '3 de 0 componente');
    });

    test('English is unaffected: zero falls in the other category', () async {
      final l10n = await load('en');

      expect(l10n.diveSites_list_tile_diveCount(0), '0 dives');
      expect(l10n.diveSites_list_tile_diveCount(1), '1 dive');
      expect(l10n.equipment_components_countOfTotal(3, 0), '3 of 0 components');
    });
  });

  group('the two keys that leaked English into fr and pt are translated', () {
    Future<AppLocalizations> load(String languageCode) =>
        AppLocalizations.delegate.load(Locale(languageCode));

    test('French', () async {
      final l10n = await load('fr');

      expect(l10n.diveLog_detail_customFieldCount(0), '0 champ');
      expect(l10n.diveLog_detail_customFieldCount(2), '2 champs');
      expect(l10n.trips_itinerary_diveCount(0), '0 plongée');
      expect(l10n.trips_itinerary_diveCount(2), '2 plongées');
    });

    test('Portuguese', () async {
      final l10n = await load('pt');

      expect(l10n.diveLog_detail_customFieldCount(0), '0 campo');
      expect(l10n.diveLog_detail_customFieldCount(2), '2 campos');
      expect(l10n.trips_itinerary_diveCount(0), '0 mergulho');
      expect(l10n.trips_itinerary_diveCount(2), '2 mergulhos');
    });
  });
}

final _pluralArgument = RegExp(r'\{\s*(\w+)\s*,\s*plural\s*,');
final _selector = RegExp(r'\s*(=\d+|\w+)\s*\{');
final _wordCharacter = RegExp(r'\w');

/// Calls [visit] once per `{name, plural, ...}` argument in [message], with the
/// argument's name and its selector-to-branch-text map.
///
/// A message can hold more than one plural argument, including one nested in
/// another's branch text, so this walks every match rather than the first.
void forEachPluralArgument(
  String message,
  void Function(String argument, Map<String, String> branches) visit,
) {
  for (final match in _pluralArgument.allMatches(message)) {
    final close = _matchingBrace(message, match.start);
    visit(match.group(1)!, _branches(message, match.end, close));
  }
}

/// Whether [text] uses `1` as a standalone number rather than inside a word or
/// a longer number, so "1 plongée" counts but "100" and "v1" do not.
bool containsBareOne(String text) {
  for (var i = 0; i < text.length; i++) {
    if (text[i] != '1') continue;
    final before = i == 0 ? '' : text[i - 1];
    final after = i + 1 >= text.length ? '' : text[i + 1];
    if (!_wordCharacter.hasMatch(before) && !_wordCharacter.hasMatch(after)) {
      return true;
    }
  }
  return false;
}

/// Splits `=1{...} other{...}` selectors out of a plural argument's body, which
/// spans [start] up to (not including) [end].
Map<String, String> _branches(String message, int start, int end) {
  final branches = <String, String>{};
  var cursor = start;
  while (cursor < end) {
    final match = _selector.matchAsPrefix(message, cursor);
    if (match == null) break;
    final open = match.end - 1;
    final close = _matchingBrace(message, open);
    branches[match.group(1)!] = message.substring(open + 1, close);
    cursor = close + 1;
  }
  return branches;
}

/// Index of the `}` that closes the `{` at [open].
int _matchingBrace(String message, int open) {
  var depth = 0;
  for (var i = open; i < message.length; i++) {
    if (message[i] == '{') {
      depth++;
    } else if (message[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  throw FormatException('unbalanced braces in: $message');
}
