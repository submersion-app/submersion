import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_currency_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';

import '../../../../helpers/test_database.dart';
import 'record_harness.dart';

void main() {
  late AppDatabase db;
  late RecordHarness h;
  const t = kSeedTime;

  setUp(() async {
    db = await setUpTestDatabase();
    h = RecordHarness(db);
    await seedTwoDivers(db);
    for (final (id, owner) in [('bud-a', kDiverA), ('bud-b', kDiverB)]) {
      await db
          .into(db.buddies)
          .insert(
            BuddiesCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
              email: const Value('b@example.com'),
              phone: const Value('+1 555'),
              photo: Value(Uint8List.fromList([1, 2, 3])),
            ),
          );
    }
    for (final (id, owner, buddy) in [
      ('cert-a', kDiverA, null),
      ('cert-b', kDiverB, null),
      ('cert-bud', null, 'bud-a'),
      ('cert-bud-b', null, 'bud-b'),
    ]) {
      await db
          .into(db.certifications)
          .insert(
            CertificationsCompanion.insert(
              id: id,
              name: id,
              agency: 'padi',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
              buddyId: Value(buddy),
              cardNumber: const Value('N-123'),
              issueDate: Value(DateTime(2020, 5, 1).millisecondsSinceEpoch),
              photoFront: Value(Uint8List.fromList([7, 7])),
            ),
          );
    }
    await db
        .into(db.certificationCurrencyRules)
        .insert(
          CertificationCurrencyRulesCompanion.insert(
            id: 'rule-a',
            name: 'Rule A',
            clockKind: 'lastDive',
            lapseDays: 365,
            leadDays: 30,
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
    await db
        .into(db.certificationCurrencyRules)
        .insert(
          CertificationCurrencyRulesCompanion.insert(
            id: 'rule-b',
            name: 'Rule B',
            clockKind: 'lastDive',
            lapseDays: 365,
            leadDays: 30,
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverB),
          ),
        );
    for (final id in ['cert-a', 'cert-b']) {
      await db
          .into(db.certificationCurrencyPrefs)
          .insert(
            CertificationCurrencyPrefsCompanion.insert(
              id: 'pref-$id',
              certificationId: id,
              ruleId: 'rule-a',
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.certificationCurrencyEvents)
          .insert(
            CertificationCurrencyEventsCompanion.insert(
              id: 'event-$id',
              certificationId: id,
              eventType: 'refresher',
              eventDate: DateTime(2024, 2, 2).millisecondsSinceEpoch,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    for (final (id, owner, shared) in [
      ('ag-a', kDiverA, false),
      ('ag-b', kDiverB, false),
      ('ag-open', kDiverB, true),
    ]) {
      await db
          .into(db.customCertificationAgencies)
          .insert(
            CustomCertificationAgenciesCompanion.insert(
              id: id,
              diverId: owner,
              name: id,
              colorArgb: 123,
              createdAt: t,
              updatedAt: t,
              isShared: Value(shared),
            ),
          );
      await db
          .into(db.customCertificationLevels)
          .insert(
            CustomCertificationLevelsCompanion.insert(
              id: 'lv-$id',
              diverId: owner,
              agencyId: id,
              name: id,
              isProgression: true,
              createdAt: t,
              updatedAt: t,
              isShared: Value(shared),
            ),
          );
    }
    for (final (id, owner) in [('course-a', kDiverA), ('course-b', kDiverB)]) {
      await db
          .into(db.courses)
          .insert(
            CoursesCompanion.insert(
              id: id,
              diverId: owner,
              name: id,
              agency: 'padi',
              startDate: DateTime(2024, 1, 10).millisecondsSinceEpoch,
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.courseRequirements)
          .insert(
            CourseRequirementsCompanion.insert(
              id: 'req-$id',
              courseId: id,
              name: 'Four dives',
              kind: 'dives',
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion.insert(
            id: 'turtle',
            commonName: 'Turtle',
            category: 'turtle',
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  group('buddies', () {
    test(
      'a buddy document carries contact details and no photo bytes',
      () async {
        final doc = (await h.one('buddies', 'bud-a'))!;
        expect(doc['email'], 'b@example.com');
        expect(doc['phone'], '+1 555');
        expect(doc.keys, isNot(contains('photo')));
      },
    );

    test('a buddy\'s certifications arrive as a block', () async {
      final doc = (await h.one(
        'buddies',
        'bud-a',
        include: ['certifications'],
      ))!;
      expect(
        (doc['certifications'] as List).cast<Map>().single['id'],
        'cert-bud',
      );
    });

    test('scope matches getAllBuddies', () async {
      final expected = {
        for (final b in await BuddyRepository().getAllBuddies(diverId: kDiverA))
          b.id,
      };
      final out = await h.get('buddies', ['bud-a', 'bud-b']);
      expect(
        (out['records'] as List).cast<Map>().map((r) => r['id']).toSet(),
        expected,
      );
    });
  });

  group('certifications', () {
    test('a card number is present', () async {
      final doc = (await h.one('certifications', 'cert-a'))!;
      expect(doc['card_number'], 'N-123');
      expect(doc['issue_date'], '2020-05-01');
    });

    test('a certification\'s card images never appear', () async {
      final doc = (await h.one('certifications', 'cert-a'))!;
      expect(doc.keys, isNot(contains('photo_front')));
      expect(doc.keys, isNot(contains('photo_back')));
      expect(doc.values, isNot(contains(isA<Uint8List>())));
    });

    test('a buddy\'s certification reads for the buddy\'s owner', () async {
      expect(await h.one('certifications', 'cert-bud'), isNotNull);
      expect(await h.one('certifications', 'cert-bud-b'), isNull);
    });

    test('blocks arrive when named', () async {
      final doc = (await h.one(
        'certifications',
        'cert-a',
        include: ['currency_prefs', 'currency_events'],
      ))!;
      expect((doc['currency_prefs'] as List), hasLength(1));
      expect((doc['currency_events'] as List), hasLength(1));
    });

    test('scope covers getAllCertifications', () async {
      final expected = {
        for (final c in await CertificationRepository().getAllCertifications(
          diverId: kDiverA,
        ))
          c.id,
      };
      final out = await h.get('certifications', ['cert-a', 'cert-b']);
      expect(
        (out['records'] as List).cast<Map>().map((r) => r['id']).toSet(),
        expected,
      );
    });
  });

  group('currency', () {
    test('prefs and events follow their certification', () async {
      for (final (entity, own, other) in [
        ('currency_prefs', 'pref-cert-a', 'pref-cert-b'),
        ('currency_events', 'event-cert-a', 'event-cert-b'),
      ]) {
        expect((await h.one(entity, own))!['certification_id'], 'cert-a');
        expect(await h.one(entity, other), isNull);
        expect(await h.list(entity, parentId: 'cert-a'), [own]);
      }
    });

    test('a pref lists its counted dive modes', () async {
      await (db.update(
        db.certificationCurrencyPrefs,
      )..where((p) => p.id.equals('pref-cert-a'))).write(
        const CertificationCurrencyPrefsCompanion(
          countedDiveModes: Value('["ccr"]'),
        ),
      );
      final doc = (await h.one('currency_prefs', 'pref-cert-a'))!;
      expect(doc['counted_dive_modes'], ['ccr']);
    });

    test('an event date is a calendar date', () async {
      expect(
        (await h.one('currency_events', 'event-cert-a'))!['event_date'],
        '2024-02-02',
      );
    });

    test('built-in currency rules read for every profile', () async {
      final expected = {
        for (final x
            in await CertificationCurrencyRepository().getRulesForDiver(
              kDiverA,
            ))
          x.id,
      };
      expect((await h.list('currency_rules')).toSet(), expected);
      expect(expected, contains('rule-a'));
      expect(expected, isNot(contains('rule-b')));
    });
  });

  group('custom agencies', () {
    test('a shared custom agency reads for every profile', () async {
      expect(await h.one('custom_agencies', 'ag-open'), isNotNull);
      expect(await h.one('custom_agencies', 'ag-b'), isNull);
      expect((await h.list('custom_agencies')).toSet(), {'ag-a', 'ag-open'});
    });

    test('levels list by agency', () async {
      expect(await h.list('custom_levels', parentId: 'ag-a'), ['lv-ag-a']);
      expect((await h.one('custom_levels', 'lv-ag-a'))!['agency_id'], 'ag-a');
    });
  });

  group('courses', () {
    test('requirements follow their course', () async {
      final doc = (await h.one('course_requirements', 'req-course-a'))!;
      expect(doc['course_id'], 'course-a');
      expect(doc['target_count'], 1);
      expect(await h.one('course_requirements', 'req-course-b'), isNull);
      expect(await h.list('course_requirements', parentId: 'course-a'), [
        'req-course-a',
      ]);
    });

    test('blocks arrive when named', () async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'dive',
              diveDateTime: t,
              createdAt: t,
              updatedAt: t,
              diverId: const Value(kDiverA),
            ),
          );
      await db
          .into(db.diveCourses)
          .insert(
            DiveCoursesCompanion.insert(
              id: 'link',
              diveId: 'dive',
              courseId: 'course-a',
              createdAt: t,
            ),
          );
      final doc = (await h.one(
        'courses',
        'course-a',
        include: ['requirements', 'dive_ids'],
      ))!;
      expect((doc['requirements'] as List), hasLength(1));
      expect(doc['dive_ids'], ['dive']);
    });

    test('a start date is a calendar date', () async {
      expect((await h.one('courses', 'course-a'))!['start_date'], '2024-01-10');
    });

    test('scope matches getAllCourses', () async {
      final expected = {
        for (final c in await CourseRepository().getAllCourses(
          diverId: kDiverA,
        ))
          c.id,
      };
      final out = await h.get('courses', ['course-a', 'course-b']);
      expect(
        (out['records'] as List).cast<Map>().map((r) => r['id']).toSet(),
        expected,
      );
    });
  });

  test('species read for every profile', () async {
    final doc = (await h.one('species', 'turtle', diverId: kDiverB))!;
    expect(doc['common_name'], 'Turtle');
    expect(doc['category'], 'turtle');
  });
}
