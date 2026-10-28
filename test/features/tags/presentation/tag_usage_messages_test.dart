import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_usage_messages.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _d = TagScope.dives;
const _s = TagScope.sites;
const _e = TagScope.equipment;
const _m = TagScope.media;
const _doc = TagScope.documents;

/// One combination of affected scopes and the English each family gives it.
typedef _Case = ({
  String name,
  Map<TagScope, int> usage,
  String delete,
  String bulk,
  String merge,
});

/// Affected-scope combinations (#1902, #1942, #1970). A single scope gets one
/// whole sentence; two or more get a heading and one count line per scope,
/// in registry order.
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
    name: 'media only',
    usage: {_m: 1},
    delete: '"Reef" will be removed from 1 media item. This cannot be undone.',
    bulk:
        'These tags will be removed from 1 media item total. '
        'This cannot be undone.',
    merge: 'This will affect 1 media item total.',
  ),
  (
    name: 'documents only',
    usage: {_doc: 4},
    delete: '"Reef" will be removed from 4 documents. This cannot be undone.',
    bulk:
        'These tags will be removed from 4 documents total. '
        'This cannot be undone.',
    merge: 'This will affect 4 documents total.',
  ),
  (
    name: 'dives and sites',
    usage: {_d: 12, _s: 1},
    delete:
        '"Reef" will be removed from:\n• 12 dives\n• 1 site\n'
        'This cannot be undone.',
    bulk:
        'These tags will be removed from:\n• 12 dives\n• 1 site\n'
        'This cannot be undone.',
    merge: 'This will affect:\n• 12 dives\n• 1 site',
  ),
  (
    name: 'media and documents',
    usage: {_doc: 2, _m: 7},
    delete:
        '"Reef" will be removed from:\n• 7 media items\n• 2 documents\n'
        'This cannot be undone.',
    bulk:
        'These tags will be removed from:\n• 7 media items\n'
        '• 2 documents\nThis cannot be undone.',
    merge: 'This will affect:\n• 7 media items\n• 2 documents',
  ),
  (
    name: 'every scope',
    usage: {_d: 12, _s: 3, _e: 5, _m: 1, _doc: 1},
    delete:
        '"Reef" will be removed from:\n• 12 dives\n• 3 sites\n'
        '• 5 equipment items\n• 1 media item\n• 1 document\n'
        'This cannot be undone.',
    bulk:
        'These tags will be removed from:\n• 12 dives\n• 3 sites\n'
        '• 5 equipment items\n• 1 media item\n• 1 document\n'
        'This cannot be undone.',
    merge:
        'This will affect:\n• 12 dives\n• 3 sites\n'
        '• 5 equipment items\n• 1 media item\n• 1 document',
  ),
  (
    name: 'nothing',
    usage: {_d: 0, _s: 0, _e: 0, _m: 0, _doc: 0},
    delete: '"Reef" is not used anywhere. This cannot be undone.',
    bulk: 'These tags are not used anywhere. This cannot be undone.',
    merge: 'These tags are not used anywhere.',
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
      '"Reef" is not used anywhere. This cannot be undone.',
    );
    expect(
      tagsMergeAffectedMessage(l10n, const {_e: 5}),
      'This will affect 5 equipment items total.',
    );
  });

  group('tagUsageCounts', () {
    const all = {_d, _s, _e, _m, _doc};

    test('shows dives alone when nothing else carries the tag', () {
      expect(tagUsageCounts(l10n, const {_d: 12}, offered: all), '12 dives');
    });

    test('names only the scopes that carry the tag (#3746)', () {
      expect(
        tagUsageCounts(l10n, const {_s: 3}, offered: const {_d, _s}),
        '3 sites',
      );
      expect(
        tagUsageCounts(l10n, const {_e: 5}, offered: const {_e}),
        '5 equipment items',
      );
      expect(
        tagUsageCounts(l10n, const {_d: 1, _e: 1}, offered: all),
        '1 dive, 1 equipment item',
      );
    });

    test('an unused tag counts zero of its first offered scope (#3746)', () {
      expect(tagUsageCounts(l10n, const {}, offered: const {_d}), '0 dives');
      expect(
        tagUsageCounts(l10n, const {_s: 0}, offered: const {_e, _s}),
        '0 sites',
      );
    });

    test('an unused tag offered nowhere still counts zero dives', () {
      expect(tagUsageCounts(l10n, const {}, offered: const {}), '0 dives');
    });

    test('lists every scope in registry order', () {
      expect(
        tagUsageCounts(l10n, const {_e: 5, _s: 3, _d: 12}, offered: all),
        '12 dives, 3 sites, 5 equipment items',
      );
    });

    test('adds media items and documents when some carry the tag (#1970)', () {
      expect(
        tagUsageCounts(l10n, const {_doc: 1, _m: 2, _d: 3}, offered: all),
        '3 dives, 2 media items, 1 document',
      );
    });

    test('leaves out a zero site or equipment count', () {
      expect(
        tagUsageCounts(l10n, const {_d: 2, _s: 0, _e: 0}, offered: all),
        '2 dives',
      );
    });
  });
}
