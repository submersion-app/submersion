import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/features/table_editor/entities/site_table_editor_entity.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../helpers/test_database.dart';

/// The sites tab (#3422): library sites keep the library's values, and a
/// site's two coordinate columns save as one pair.
void main() {
  late SiteRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = SiteRepository();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> seed(
    String id, {
    GeoPoint? location,
    String? sharedLibraryId,
    String? hazards,
  }) => repo.createSite(
    DiveSite(
      id: id,
      name: 'Site $id',
      location: location,
      sharedLibraryId: sharedLibraryId,
      hazards: hazards,
      country: 'Mexico',
    ),
  );

  Future<SiteWithCount> row(String id) async =>
      SiteWithDiveCount(site: (await repo.getSiteById(id))!, diveCount: 0);

  SiteTableEditorEntity entity({Map<String, bool> library = const {}}) =>
      SiteTableEditorEntity(repo: repo, editableLibrarySites: library);

  TableDraft draft(String id, SiteField f, Object? original, Object? value) =>
      TableDraft(
        entityId: id,
        fieldName: f.name,
        original: original,
        value: value,
      );

  test('library site the profile may not edit: only notes and rating are '
      'editable', () async {
    await seed('s1', sharedLibraryId: 'lib1');
    final e = entity(library: {'s1': false});
    final r = await row('s1');

    expect(e.columnFor(SiteField.siteName)!.isEditable(r), isFalse);
    expect(e.columnFor(SiteField.latitude)!.isEditable(r), isFalse);
    expect(e.columnFor(SiteField.notes)!.isEditable(r), isTrue);
    expect(e.columnFor(SiteField.rating)!.isEditable(r), isTrue);
    expect(
      e.columnFor(SiteField.siteName)!.readOnlyReason(r, AppLocalizationsEn()),
      isNotNull,
    );
  });

  test('a library site the profile may edit is fully editable', () async {
    await seed('s1', sharedLibraryId: 'lib1');
    final e = entity(library: {'s1': true});

    expect(
      e.columnFor(SiteField.siteName)!.isEditable(await row('s1')),
      isTrue,
    );
  });

  test('one half drafted on a site without coordinates is flagged '
      'pairIncomplete', () async {
    await seed('s1');
    final e = entity();

    final out = e.reconcile(await row('s1'), [
      draft('s1', SiteField.latitude, null, 10.0),
    ]);

    expect(out.single.flag, TableDraftFlag.pairIncomplete);
  });

  test(
    'both halves drafted on a site without coordinates clear the flag',
    () async {
      await seed('s1');
      final e = entity();

      final out = e.reconcile(await row('s1'), [
        draft(
          's1',
          SiteField.latitude,
          null,
          10.0,
        ).copyWith(flag: TableDraftFlag.pairIncomplete),
        draft('s1', SiteField.longitude, null, 20.0),
      ]);

      expect(out.map((d) => d.flag), [null, null]);
    },
  );

  test('clearing one half on a site with coordinates adds a draft clearing '
      'the other', () async {
    await seed('s1', location: const GeoPoint(1, 2));
    final e = entity();

    final out = e.reconcile(await row('s1'), [
      draft('s1', SiteField.latitude, 1.0, null),
    ]);

    expect(out, hasLength(2));
    final lon = out.firstWhere((d) => d.fieldName == SiteField.longitude.name);
    expect(lon.original, 2.0);
    expect(lon.value, isNull);
    expect(e.summaryNotes(out, AppLocalizationsEn()), isNotEmpty);
  });

  test('save writes name and coordinates and keeps other fields', () async {
    await seed('s1');
    final e = entity();
    final r = await row('s1');

    await e.save(
      {
        's1': [
          draft('s1', SiteField.siteName, 'Site s1', 'Blue Hole'),
          draft('s1', SiteField.latitude, null, 17.3),
          draft('s1', SiteField.longitude, null, -87.5),
          draft('s1', SiteField.waterType, null, WaterType.salt.name),
        ],
      },
      {'s1': r},
    );

    final after = (await repo.getSiteById('s1'))!;
    expect(after.name, 'Blue Hole');
    expect(after.location, const GeoPoint(17.3, -87.5));
    expect(after.waterType, WaterType.salt);
    expect(after.country, 'Mexico');
  });

  test('save clears a text field and a multi-value field', () async {
    await seed('s1', hazards: 'Boats');
    final e = entity();
    final r = await row('s1');

    await e.save(
      {
        's1': [
          draft('s1', SiteField.hazards, 'Boats', null),
          draft('s1', SiteField.entryType, <String>[], ['shore', 'boat']),
        ],
      },
      {'s1': r},
    );

    final after = (await repo.getSiteById('s1'))!;
    expect(after.hazards, isNull);
    expect(after.entryMethods, [EntryMethod.shore, EntryMethod.boat]);
    expect(e.nameOf(r), 'Site s1');
    expect(e.numberOf(r), isNull);
  });

  group('country code (issue #4426)', () {
    Future<void> seedKorea() => repo.createSite(
      const DiveSite(
        id: 's1',
        name: 'Site s1',
        country: 'Korea',
        countryCode: 'KR',
      ),
    );

    test('an edit elsewhere keeps the stored code', () async {
      await seedKorea();
      await entity().save(
        {
          's1': [draft('s1', SiteField.siteName, 'Site s1', 'Jeju Wall')],
        },
        {'s1': await row('s1')},
      );

      expect((await repo.getSiteById('s1'))!.countryCode, 'KR');
    });

    test('an edited country is read afresh', () async {
      await seedKorea();
      await entity().save(
        {
          's1': [draft('s1', SiteField.country, 'Korea', 'Spain')],
        },
        {'s1': await row('s1')},
      );

      expect((await repo.getSiteById('s1'))!.countryCode, 'ES');
    });
  });

  test('reload returns fresh rows by id', () async {
    await seed('s1');
    await seed('s2');
    final fresh = await entity().reload(['s1', 's2']);

    expect(fresh.map((r) => r.site.id), containsAll(['s1', 's2']));
  });

  test(
    'typing one half again after a clear keeps the stored other half',
    () async {
      await seed('s1', location: const GeoPoint(1, 2));
      final e = entity();
      final r = await row('s1');
      final cleared = e.reconcile(r, [
        draft('s1', SiteField.latitude, 1.0, null),
      ]);
      expect(cleared.every((d) => d.value == null), isTrue);

      final retyped = e.reconcile(r, [
        ...cleared.where((d) => d.fieldName != SiteField.latitude.name),
        draft('s1', SiteField.latitude, 1.0, 5.0),
      ]);

      final lat = retyped.firstWhere(
        (d) => d.fieldName == SiteField.latitude.name,
      );
      final lon = retyped.firstWhere(
        (d) => d.fieldName == SiteField.longitude.name,
      );
      expect(lat.value, 5.0);
      expect(lon.value, 2.0);
    },
  );

  group('coordinate pair upkeep', () {
    test(
      'clearing both halves of a site with no position leaves no flags',
      () async {
        await seed('s1');
        final r = await row('s1');

        final out = entity().reconcile(r, [
          draft('s1', SiteField.latitude, null, null),
          draft(
            's1',
            SiteField.longitude,
            null,
            null,
          ).copyWith(flag: TableDraftFlag.pairIncomplete),
        ]);

        expect(out.map((d) => d.flag), everyElement(isNull));
      },
    );

    test('discarding one typed half flags the other', () async {
      await seed('s1');
      final out = entity().afterDiscard(await row('s1'), [
        draft('s1', SiteField.latitude, null, 20.0),
        draft('s1', SiteField.longitude, null, -87.0),
      ], SiteField.latitude.name);

      expect(out.single.fieldName, SiteField.longitude.name);
      expect(out.single.flag, TableDraftFlag.pairIncomplete);
    });

    test('discarding a cleared half brings the whole position back', () async {
      await seed('s1', location: const GeoPoint(20, -87));
      final out = entity().afterDiscard(await row('s1'), [
        draft('s1', SiteField.latitude, 20.0, null),
        draft('s1', SiteField.longitude, -87.0, null),
      ], SiteField.latitude.name);

      expect(out, isEmpty);
    });
  });

  // Issue #5073: the contact columns edit, and a save keeps what the table
  // does not show.
  test('editing the phone keeps the address, website and hours', () async {
    final hours = OpeningHours(alwaysOpen: true);
    await repo.createSite(
      DiveSite(
        id: 'c1',
        name: 'Stoney Cove',
        address: 'LE9 4DW',
        website: 'stoneycove.com',
        openingHours: hours,
      ),
    );
    final e = entity();
    final r = await row('c1');
    expect(e.columnFor(SiteField.phone)!.isEditable(r), isTrue);

    await e.save(
      {
        'c1': [draft('c1', SiteField.phone, null, '+44 1455 273089')],
      },
      {'c1': r},
    );

    final saved = (await repo.getSiteById('c1'))!;
    expect(saved.phone, '+44 1455 273089');
    expect(saved.address, 'LE9 4DW');
    expect(saved.website, 'stoneycove.com');
    expect(saved.openingHours, hours);
  });

  test('an email or website the site could not use is refused', () {
    const units = UnitFormatter(AppSettings());
    final l10n = AppLocalizationsEn();
    final e = entity();
    final website = e.columnFor(SiteField.website)!;
    final email = e.columnFor(SiteField.email)!;

    expect(website.parse('mailto:x@y.com', units, l10n), isA<CellRejected>());
    expect(website.parse('stoneycove.com', units, l10n), isA<CellParsed>());
    expect(email.parse('info@', units, l10n), isA<CellRejected>());
    expect(email.parse('info@stoneycove.com', units, l10n), isA<CellParsed>());
    // A blank still clears the field.
    expect(website.parse('', units, l10n), isA<CellParsed>());
  });
}
