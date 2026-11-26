import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide Certification;
import 'package:submersion/features/certifications/data/repositories/certification_currency_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/credential_currency.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_currency_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A certification's currency held in its page's sitting (issue #4527,
/// phase 3): written at Save, never on Cancel.
void main() {
  final t0 = DateTime(2020);
  late CertificationCurrencyRepository currency;
  late Certification ow;
  late Certification aow;

  CurrencyRule rule(String id, {String? supersedes}) => CurrencyRule(
    id: id,
    name: id,
    clockKind: CurrencyClockKind.activity,
    lapseDays: 365,
    leadDays: 30,
    supersedesRuleId: supersedes,
    createdAt: t0,
    updatedAt: t0,
  );

  CredentialCurrency member(Certification c, CurrencyRule r) =>
      CredentialCurrency(
        certification: c,
        rule: r,
        severity: CurrencySeverity.current,
        anchor: t0,
        origin: CurrencyAnchorOrigin.lastDive,
        dueDate: t0,
        lapseDays: 365,
        leadDays: 30,
      );

  /// The PADI refresher row standing for both cards.
  CurrencyGroup refresherGroup([CurrencyRule? r]) {
    final applied = r ?? rule('padi_reactivate');
    return CurrencyGroup([member(aow, applied), member(ow, applied)]);
  }

  Future<Certification> addCert(String name) =>
      CertificationRepository().createCertification(
        Certification(
          id: '',
          diverId: 'me',
          name: name,
          agency: 'padi',
          createdAt: t0,
          updatedAt: t0,
        ),
      );

  setUp(() async {
    final db = await setUpTestDatabase();
    currency = CertificationCurrencyRepository();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'Me',
            isDefault: const Value(true),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    ow = await addCert('Open Water');
    aow = await addCert('Advanced');
  });

  tearDown(tearDownTestDatabase);

  group('prefs', () {
    test(
      'a preference on a collapsed group writes every member\'s at Save',
      () async {
        final session = EditSession(aow);
        addTearDown(session.dispose);
        final g = refresherGroup();

        holdCurrencyPrefs(
          session,
          g,
          await storedCurrencyPrefs(g),
          (p) => rebuildCurrencyPref(p, muted: true),
        );

        expect(session.changedCardIds, {'currency'});
        expect(await currency.getPrefs(aow.id), isEmpty);
        await session.runHeldWrites();
        for (final c in [ow, aow]) {
          expect((await currency.getPrefs(c.id)).single.muted, isTrue);
        }
      },
    );

    test('Cancel writes no preference', () async {
      final session = EditSession(aow);
      final g = refresherGroup();
      holdCurrencyPrefs(
        session,
        g,
        await storedCurrencyPrefs(g),
        (p) => rebuildCurrencyPref(p, lapse: 900),
      );

      session.dispose();

      for (final c in [ow, aow]) {
        expect(await currency.getPrefs(c.id), isEmpty);
      }
    });

    test('a change taken back is no longer held', () async {
      final session = EditSession(aow);
      addTearDown(session.dispose);
      final g = refresherGroup();
      final stored = await storedCurrencyPrefs(g);
      final now = DateTime(2024);

      holdCurrencyPrefs(
        session,
        g,
        stored,
        (p) => rebuildCurrencyPref(p, muted: true),
        now: now,
      );
      holdCurrencyPrefs(
        session,
        g,
        stored,
        (p) => rebuildCurrencyPref(p, muted: false),
        now: now,
      );

      expect(session.isDirty, isFalse);
      expect(currencyPrefsInSitting(session), isEmpty);
    });

    test('a new preference set and set back is no longer held', () async {
      final session = EditSession(aow);
      addTearDown(session.dispose);
      final g = refresherGroup();
      final stored = await storedCurrencyPrefs(g);

      // Separate actions make the new rows at different times.
      holdCurrencyPrefs(
        session,
        g,
        stored,
        (p) => rebuildCurrencyPref(p, lapse: 900),
        now: DateTime(2024),
      );
      holdCurrencyPrefs(
        session,
        g,
        stored,
        (p) => rebuildCurrencyPref(p, lapse: null),
        now: DateTime(2025),
      );

      expect(session.isDirty, isFalse);
    });

    test('two changes in a sitting compose', () async {
      final session = EditSession(aow);
      addTearDown(session.dispose);
      final g = refresherGroup();
      final stored = await storedCurrencyPrefs(g);

      holdCurrencyPrefs(
        session,
        g,
        stored,
        (p) => rebuildCurrencyPref(p, muted: true),
      );
      holdCurrencyPrefs(
        session,
        g,
        stored,
        (p) => rebuildCurrencyPref(p, lapse: 900),
      );
      await session.runHeldWrites();

      final pref = (await currency.getPrefs(aow.id)).single;
      expect(pref.muted, isTrue);
      expect(pref.lapseDaysOverride, 900);
    });

    test('prefs fall back to the inherited pref as today', () {
      final mine = rule('mine', supersedes: 'padi_reactivate');
      final inherited = CurrencyPref(
        id: 'p1',
        certificationId: aow.id,
        ruleId: 'padi_reactivate',
        muted: true,
        leadDaysOverride: 10,
        createdAt: t0,
        updatedAt: t0,
      );

      final prefs = currencyPrefsFor(CurrencyGroup([member(aow, mine)]), {
        (certificationId: aow.id, ruleId: 'padi_reactivate'): inherited,
      }, (p) => rebuildCurrencyPref(p, lapse: 300));

      final pref = prefs.single;
      expect(pref.id, '');
      expect(pref.ruleId, 'mine');
      expect(pref.muted, isTrue);
      expect(pref.leadDaysOverride, 10);
      expect(pref.lapseDaysOverride, 300);
    });

    // Issue #4942: an unreadable mapping decodes to "any dive". Carried onto
    // a copy's new row it would be written as "any"; the copy inherits the
    // rule's mapping instead, as the engine applied it.
    test('a rebuild keeps an unreadable mapping only while untouched', () {
      final unreadable = CurrencyPref(
        id: 'p1',
        certificationId: aow.id,
        ruleId: 'padi_reactivate',
        countedDiveTypeIds: const [],
        unreadableMapping: true,
        createdAt: t0,
        updatedAt: t0,
      );

      expect(
        rebuildCurrencyPref(unreadable, muted: true).unreadableMapping,
        isTrue,
      );
      expect(
        rebuildCurrencyPref(
          unreadable,
          types: const ['boat'],
          modes: const <DiveMode>[],
        ).unreadableMapping,
        isFalse,
      );
    });

    test(
      'a re-picked mapping differs from an unreadable one it decodes as',
      () {
        final stored = CurrencyPref(
          id: 'p1',
          certificationId: aow.id,
          ruleId: 'padi_reactivate',
          countedDiveTypeIds: const [],
          countedDiveModes: const [],
          unreadableMapping: true,
          storedMapping: (types: '[]', modes: '["modeFromTheFuture"]'),
          createdAt: t0,
          updatedAt: t0,
        );
        final picked = rebuildCurrencyPref(
          stored,
          types: const <String>[],
          modes: const <DiveMode>[],
        );

        expect(sameCurrencyPrefValues(picked, stored), isFalse);
        expect(picked.storedMapping, isNull);
        expect(
          sameCurrencyPrefValues(rebuildCurrencyPref(stored), stored),
          isTrue,
        );
      },
    );

    test('a copy does not carry an unreadable inherited mapping', () {
      final mine = rule('mine', supersedes: 'padi_reactivate');
      final inherited = CurrencyPref(
        id: 'p1',
        certificationId: aow.id,
        ruleId: 'padi_reactivate',
        countedDiveTypeIds: const [],
        countedDiveModes: const [],
        unreadableMapping: true,
        muted: true,
        createdAt: t0,
        updatedAt: t0,
      );

      final pref = currencyPrefsFor(CurrencyGroup([member(aow, mine)]), {
        (certificationId: aow.id, ruleId: 'padi_reactivate'): inherited,
      }, (p) => rebuildCurrencyPref(p, lapse: 300)).single;

      expect(pref.countedDiveTypeIds, isNull);
      expect(pref.countedDiveModes, isNull);
      expect(pref.muted, isTrue);
    });
  });

  group('events', () {
    test('a logged event is written at Save', () async {
      final session = EditSession(aow);
      addTearDown(session.dispose);
      await certificationEventsList.load(session);
      final event = newCurrencyEvent(
        certificationId: aow.id,
        ruleId: 'padi_reactivate',
        type: CurrencyEventType.refresher,
        date: DateTime(2024, 5, 1),
      );

      certificationEventsList.set(session, [event]);
      expect(await currency.getEvents(aow.id), isEmpty);
      await session.runHeldWrites();

      final stored = await currency.getEvents(aow.id);
      expect(stored.single.id, event.id);
      expect(stored.single.eventType, CurrencyEventType.refresher);
    });

    test('a deleted event is deleted at Save', () async {
      final kept = await currency.createEvent(
        CurrencyEvent(
          id: '',
          certificationId: aow.id,
          ruleId: 'padi_reactivate',
          eventType: CurrencyEventType.renewal,
          eventDate: DateTime(2023),
          createdAt: t0,
          updatedAt: t0,
        ),
      );
      final session = EditSession(aow);
      addTearDown(session.dispose);
      await certificationEventsList.load(session);

      certificationEventsList.set(session, const []);
      expect(await currency.getEvents(aow.id), hasLength(1));
      await session.runHeldWrites();

      expect(await currency.getEvents(aow.id), isEmpty);
      expect(kept.id, isNotEmpty);
    });
  });

  test('a logged event takes its place newest first', () {
    CurrencyEvent at(String id, DateTime date) => CurrencyEvent(
      id: id,
      certificationId: 'c',
      ruleId: 'r',
      eventType: CurrencyEventType.refresher,
      eventDate: date,
      createdAt: t0,
      updatedAt: t0,
    );

    final ordered = newestEventsFirst([
      at('old', DateTime(2019)),
      at('mid', DateTime(2021)),
      at('new', DateTime(2024)),
    ]);

    expect([for (final e in ordered) e.id], ['new', 'mid', 'old']);
  });
}
