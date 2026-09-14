import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/presentation/tag_usage_messages.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A tag can be scoped to dives, sites, or both (#1849), and deleting or
/// merging it rewrites every dive and site that carries it. These messages
/// name only what is actually affected (#1902).
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('tagDeleteMessage', () {
    test('names dives only', () {
      expect(
        tagDeleteMessage(l10n, 'Wreck', dives: 12, sites: 0),
        '"Wreck" will be removed from 12 dives. This cannot be undone.',
      );
    });

    test('names sites only, the case #1902 reported', () {
      expect(
        tagDeleteMessage(l10n, 'To try', dives: 0, sites: 3),
        '"To try" will be removed from 3 sites. This cannot be undone.',
      );
    });

    test('names dives and sites', () {
      expect(
        tagDeleteMessage(l10n, 'Reef', dives: 12, sites: 1),
        '"Reef" will be removed from 12 dives and 1 site. '
        'This cannot be undone.',
      );
    });

    test('says an unused tag is on nothing', () {
      expect(
        tagDeleteMessage(l10n, 'Old', dives: 0, sites: 0),
        '"Old" is not used on any dives or sites. This cannot be undone.',
      );
    });
  });

  group('tagsBulkDeleteMessage', () {
    test('names dives only', () {
      expect(
        tagsBulkDeleteMessage(l10n, dives: 1, sites: 0),
        'These tags will be removed from 1 dive total. This cannot be undone.',
      );
    });

    test('names sites only', () {
      expect(
        tagsBulkDeleteMessage(l10n, dives: 0, sites: 4),
        'These tags will be removed from 4 sites total. '
        'This cannot be undone.',
      );
    });

    test('names dives and sites', () {
      expect(
        tagsBulkDeleteMessage(l10n, dives: 7, sites: 2),
        'These tags will be removed from 7 dives and 2 sites total. '
        'This cannot be undone.',
      );
    });

    test('says unused tags are on nothing', () {
      expect(
        tagsBulkDeleteMessage(l10n, dives: 0, sites: 0),
        'These tags are not used on any dives or sites. '
        'This cannot be undone.',
      );
    });
  });

  group('tagsMergeAffectedMessage', () {
    test('names dives only', () {
      expect(
        tagsMergeAffectedMessage(l10n, dives: 14, sites: 0),
        'This will affect 14 dives total.',
      );
    });

    test('names sites only', () {
      expect(
        tagsMergeAffectedMessage(l10n, dives: 0, sites: 1),
        'This will affect 1 site total.',
      );
    });

    test('names dives and sites', () {
      expect(
        tagsMergeAffectedMessage(l10n, dives: 3, sites: 5),
        'This will affect 3 dives and 5 sites total.',
      );
    });

    test('says unused tags affect nothing', () {
      expect(
        tagsMergeAffectedMessage(l10n, dives: 0, sites: 0),
        'These tags are not used on any dives or sites.',
      );
    });
  });

  group('tagUsageCounts', () {
    test('shows dives alone when no site carries the tag', () {
      expect(tagUsageCounts(l10n, dives: 12, sites: 0), '12 dives');
    });

    test('adds sites when some carry the tag', () {
      expect(tagUsageCounts(l10n, dives: 0, sites: 3), '0 dives, 3 sites');
    });
  });
}
