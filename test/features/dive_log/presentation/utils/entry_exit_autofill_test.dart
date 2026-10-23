import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/utils/entry_exit_autofill.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  DiveSite site({EntryMethod? entry, EntryMethod? exit}) => DiveSite(
    id: 's',
    name: 'S',
    entryMethods: [?entry],
    exitMethods: [?exit],
  );

  group('entryExitAfterSiteAssign', () {
    test('clearing the site changes nothing', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: EntryMethod.shore,
        currentLinked: true,
        site: null,
      );
      expect(result.entry, EntryMethod.shore);
      expect(result.exit, EntryMethod.shore);
      expect(result.linked, isTrue);
    });

    test('clearing the site never materializes an exit method', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: null,
        currentLinked: true,
        site: null,
      );
      expect(result.entry, EntryMethod.shore);
      expect(result.exit, isNull);
    });

    test('a site with neither value changes nothing', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: null,
        currentLinked: true,
        site: site(),
      );
      expect(result.entry, EntryMethod.shore);
      expect(result.exit, isNull);
    });

    test('a site entry method snaps and a linked exit follows it', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: EntryMethod.shore,
        currentLinked: true,
        site: site(entry: EntryMethod.boat),
      );
      expect(result.entry, EntryMethod.boat);
      expect(result.exit, EntryMethod.boat);
      expect(result.linked, isTrue);
    });

    test('a manual exit override survives a site entry method', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: EntryMethod.ladder,
        currentLinked: false,
        site: site(entry: EntryMethod.boat),
      );
      expect(result.entry, EntryMethod.boat);
      expect(result.exit, EntryMethod.ladder);
      expect(result.linked, isFalse);
    });

    test('a manual exit override survives an explicit site exit method', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: EntryMethod.ladder,
        currentLinked: false,
        site: site(entry: EntryMethod.boat, exit: EntryMethod.boat),
      );
      expect(result.entry, EntryMethod.boat);
      expect(result.exit, EntryMethod.ladder);
      expect(result.linked, isFalse);
    });

    test('a differing site pair snaps both and breaks the link', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: EntryMethod.shore,
        currentLinked: true,
        site: site(entry: EntryMethod.giantStride, exit: EntryMethod.ladder),
      );
      expect(result.entry, EntryMethod.giantStride);
      expect(result.exit, EntryMethod.ladder);
      expect(result.linked, isFalse);
    });

    test('a new dive with nothing set takes the whole site pair', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: null,
        currentExit: null,
        currentLinked: true,
        site: site(entry: EntryMethod.giantStride, exit: EntryMethod.ladder),
      );
      expect(result.entry, EntryMethod.giantStride);
      expect(result.exit, EntryMethod.ladder);
      expect(result.linked, isFalse);
    });

    test('a site exit method alone applies without touching entry', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: EntryMethod.shore,
        currentLinked: true,
        site: site(exit: EntryMethod.ladder),
      );
      expect(result.entry, EntryMethod.shore);
      expect(result.exit, EntryMethod.ladder);
      expect(result.linked, isFalse);
    });

    test('linked is true when the resulting exit is null', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: null,
        currentExit: null,
        currentLinked: true,
        site: site(),
      );
      expect(result.exit, isNull);
      expect(result.linked, isTrue);
    });

    test('a site pair that matches the dive relinks nothing unexpectedly', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.boat,
        currentExit: EntryMethod.boat,
        currentLinked: true,
        site: site(entry: EntryMethod.boat, exit: EntryMethod.boat),
      );
      expect(result.entry, EntryMethod.boat);
      expect(result.exit, EntryMethod.boat);
      expect(result.linked, isTrue);
    });
  });

  group('entryExitAfterSiteAssign with several site methods (#2054)', () {
    DiveSite multi({
      List<EntryMethod> entries = const [],
      List<EntryMethod> exits = const [],
    }) =>
        DiveSite(id: 'm', name: 'M', entryMethods: entries, exitMethods: exits);

    test('several entry methods leave an empty dive empty', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: null,
        currentExit: null,
        currentLinked: true,
        site: multi(entries: const [EntryMethod.shore, EntryMethod.boat]),
      );
      expect(result.entry, isNull);
      expect(result.exit, isNull);
    });

    test("several entry methods keep the dive's own entry", () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.ladder,
        currentExit: null,
        currentLinked: true,
        site: multi(entries: const [EntryMethod.shore, EntryMethod.boat]),
      );
      expect(result.entry, EntryMethod.ladder);
      expect(result.exit, isNull);
    });

    test('one entry and several exits: a linked exit does not follow', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: null,
        currentExit: null,
        currentLinked: true,
        site: multi(
          entries: const [EntryMethod.boat],
          exits: const [EntryMethod.shore, EntryMethod.ladder],
        ),
      );
      expect(result.entry, EntryMethod.boat);
      expect(result.exit, isNull);
    });

    test('one entry and several exits keep a manual exit', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: null,
        currentExit: EntryMethod.ladder,
        currentLinked: false,
        site: multi(
          entries: const [EntryMethod.boat],
          exits: const [EntryMethod.shore, EntryMethod.ladder],
        ),
      );
      expect(result.entry, EntryMethod.boat);
      expect(result.exit, EntryMethod.ladder);
    });

    test('several entries and one exit: entry kept, exit taken', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: null,
        currentExit: null,
        currentLinked: true,
        site: multi(
          entries: const [EntryMethod.shore, EntryMethod.boat],
          exits: const [EntryMethod.ladder],
        ),
      );
      expect(result.entry, isNull);
      expect(result.exit, EntryMethod.ladder);
      expect(result.linked, isFalse);
    });

    test('one entry and one exit still snap as before', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: null,
        currentExit: null,
        currentLinked: true,
        site: multi(
          entries: const [EntryMethod.boat],
          exits: const [EntryMethod.ladder],
        ),
      );
      expect(result.entry, EntryMethod.boat);
      expect(result.exit, EntryMethod.ladder);
    });
  });
}
