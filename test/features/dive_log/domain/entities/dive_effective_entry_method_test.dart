import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Issue #1427: a dive with no entry method of its own reports its site's.
void main() {
  DiveSite site({EntryMethod? entryMethod}) =>
      DiveSite(id: 'site', name: 'Site', entryMethods: [?entryMethod]);

  Dive dive({EntryMethod? entryMethod, DiveSite? site}) => Dive(
    id: 'dive',
    dateTime: DateTime(2026),
    entryMethod: entryMethod,
    site: site,
  );

  test('falls back to the site when the dive has no entry method', () {
    expect(
      dive(site: site(entryMethod: EntryMethod.shore)).effectiveEntryMethod,
      EntryMethod.shore,
    );
  });

  test("the dive's own value wins over the site's", () {
    expect(
      dive(
        entryMethod: EntryMethod.boat,
        site: site(entryMethod: EntryMethod.shore),
      ).effectiveEntryMethod,
      EntryMethod.boat,
    );
  });

  test('is null when neither the dive nor its site knows', () {
    expect(dive(site: site()).effectiveEntryMethod, isNull);
    expect(dive().effectiveEntryMethod, isNull);
  });

  test('exit method is not derived from the site', () {
    // The site-assign rule for exit depends on whether the diver has unlinked
    // exit from entry, and that flag is form state, never persisted. A
    // read-time fallback cannot reproduce it, so exit stays as stored.
    expect(dive(site: site(entryMethod: EntryMethod.shore)).exitMethod, isNull);
  });

  test('does not fall back to a site with several entry methods', () {
    const multi = DiveSite(
      id: 'site',
      name: 'Site',
      entryMethods: [EntryMethod.shore, EntryMethod.boat],
    );
    expect(dive(site: multi).effectiveEntryMethod, isNull);
  });
}
