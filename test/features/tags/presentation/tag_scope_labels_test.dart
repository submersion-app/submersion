import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_scope_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The per-scope wording of the tag screens (issue #1942) is today's
/// strings, looked up by scope.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('names each scope', () {
    expect(tagScopeName(l10n, TagScope.dives), 'Dives');
    expect(tagScopeName(l10n, TagScope.sites), 'Sites');
  });

  test('labels each scope checkbox', () {
    expect(tagScopeUseForLabel(l10n, TagScope.dives), 'Use for dives');
    expect(tagScopeUseForLabel(l10n, TagScope.sites), 'Use for sites');
  });

  test('counts each scope', () {
    expect(tagScopeCount(l10n, TagScope.dives, 1), '1 dive');
    expect(tagScopeCount(l10n, TagScope.sites, 3), '3 sites');
  });

  test('explains what turning each scope off removes', () {
    expect(
      tagScopeNarrowLine(l10n, TagScope.dives, 2),
      'This tag is on 2 dives. Turning off "Use for dives" removes it from '
      'those dives.',
    );
    expect(
      tagScopeNarrowLine(l10n, TagScope.sites, 1),
      'This tag is on 1 site. Turning off "Use for sites" removes it from '
      'that site.',
    );
  });
}
