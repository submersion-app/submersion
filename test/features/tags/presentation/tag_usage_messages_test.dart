import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_usage_messages.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _d = TagScope.dives;
const _s = TagScope.sites;
const _e = TagScope.equipment;

/// One combination of affected scopes and the English each family gives it.
typedef _Case = ({
  String name,
  Map<TagScope, int> usage,
  String delete,
  String bulk,
  String merge,
});

/// Every combination of affected scopes (#1902, #1942). A tag can carry any
/// mix of dives, sites and equipment, and each message names exactly what a
/// delete or merge rewrites, one whole sentence per combination.
const List<_Case> _cases = [
  (
    name: 'dives only',
    usage: {_d: 12},
    delete: '"Reef" will be removed from 12 dives. This cannot be undone.',
    bulk:
        'These tags will be removed from 12 dives total. '
        'This cannot be undone.',
    merge: 'This will affect 12 dives total.',
  ),
  (
    name: 'sites only',
    usage: {_s: 3},
    delete: '"Reef" will be removed from 3 sites. This cannot be undone.',
    bulk:
        'These tags will be removed from 3 sites total. '
        'This cannot be undone.',
    merge: 'This will affect 3 sites total.',
  ),
  (
    name: 'equipment only',
    usage: {_e: 5},
    delete:
        '"Reef" will be removed from 5 equipment items. '
        'This cannot be undone.',
    bulk:
        'These tags will be removed from 5 equipment items total. '
        'This cannot be undone.',
    merge: 'This will affect 5 equipment items total.',
  ),
  (
    name: 'dives and sites',
    usage: {_d: 12, _s: 1},
    delete:
        '"Reef" will be removed from 12 dives and 1 site. '
        'This cannot be undone.',
    bulk:
        'These tags will be removed from 12 dives and 1 site total. '
        'This cannot be undone.',
    merge: 'This will affect 12 dives and 1 site total.',
  ),
  (
    name: 'dives and equipment',
    usage: {_d: 1, _e: 2},
    delete:
        '"Reef" will be removed from 1 dive and 2 equipment items. '
        'This cannot be undone.',
    bulk:
        'These tags will be removed from 1 dive and 2 equipment items '
        'total. This cannot be undone.',
    merge: 'This will affect 1 dive and 2 equipment items total.',
  ),
  (
    name: 'sites and equipment',
    usage: {_s: 2, _e: 1},
    delete:
        '"Reef" will be removed from 2 sites and 1 equipment item. '
        'This cannot be undone.',
    bulk:
        'These tags will be removed from 2 sites and 1 equipment item '
        'total. This cannot be undone.',
    merge: 'This will affect 2 sites and 1 equipment item total.',
  ),
  (
    name: 'dives, sites and equipment',
    usage: {_d: 12, _s: 3, _e: 5},
    delete:
        '"Reef" will be removed from 12 dives, 3 sites, and 5 equipment '
        'items. This cannot be undone.',
    bulk:
        'These tags will be removed from 12 dives, 3 sites, and 5 '
        'equipment items total. This cannot be undone.',
    merge: 'This will affect 12 dives, 3 sites, and 5 equipment items total.',
  ),
  (
    name: 'nothing',
    usage: {_d: 0, _s: 0, _e: 0},
    delete:
        '"Reef" is not used on any dives, sites, or equipment. '
        'This cannot be undone.',
    bulk:
        'These tags are not used on any dives, sites, or equipment. '
        'This cannot be undone.',
    merge: 'These tags are not used on any dives, sites, or equipment.',
  ),
];

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('tagDeleteMessage', () {
    for (final c in _cases) {
      test('names ${c.name}', () {
        expect(tagDeleteMessage(l10n, 'Reef', c.usage), c.delete);
      });
    }
  });

  group('tagsBulkDeleteMessage', () {
    for (final c in _cases) {
      test('names ${c.name}', () {
        expect(tagsBulkDeleteMessage(l10n, c.usage), c.bulk);
      });
    }
  });

  group('tagsMergeAffectedMessage', () {
    for (final c in _cases) {
      test('names ${c.name}', () {
        expect(tagsMergeAffectedMessage(l10n, c.usage), c.merge);
      });
    }
  });

  test('each family gives every combination a message of its own', () {
    final families = <String Function(Map<TagScope, int>)>[
      (usage) => tagDeleteMessage(l10n, 'Reef', usage),
      (usage) => tagsBulkDeleteMessage(l10n, usage),
      (usage) => tagsMergeAffectedMessage(l10n, usage),
    ];
    for (final family in families) {
      expect(
        _cases.map((c) => family(c.usage)).toSet(),
        hasLength(_cases.length),
      );
    }
  });

  test('a scope missing from the usage map counts as zero', () {
    expect(
      tagDeleteMessage(l10n, 'Reef', const {}),
      '"Reef" is not used on any dives, sites, or equipment. '
      'This cannot be undone.',
    );
    expect(
      tagsMergeAffectedMessage(l10n, const {_e: 5}),
      'This will affect 5 equipment items total.',
    );
  });

  group('tagUsageCounts', () {
    test('shows dives alone when nothing else carries the tag', () {
      expect(tagUsageCounts(l10n, const {_d: 12}), '12 dives');
    });

    test('adds sites when some carry the tag', () {
      expect(tagUsageCounts(l10n, const {_s: 3}), '0 dives, 3 sites');
    });

    test('adds equipment items when some carry the tag (#1942)', () {
      expect(tagUsageCounts(l10n, const {_e: 5}), '0 dives, 5 equipment items');
      expect(
        tagUsageCounts(l10n, const {_d: 1, _e: 1}),
        '1 dive, 1 equipment item',
      );
    });

    test('lists every scope in registry order', () {
      expect(
        tagUsageCounts(l10n, const {_e: 5, _s: 3, _d: 12}),
        '12 dives, 3 sites, 5 equipment items',
      );
    });

    test('leaves out a zero site or equipment count', () {
      expect(tagUsageCounts(l10n, const {_d: 2, _s: 0, _e: 0}), '2 dives');
    });
  });
}
