import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/credential_currency.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/domain/entities/dive_activity_index.dart';
import 'package:submersion/features/certifications/domain/services/calendar_days.dart';
import 'package:submersion/features/certifications/domain/services/certification_currency_engine.dart';

final _t0 = DateTime(2026);

Certification cert(
  String id, {
  CertificationAgency agency = CertificationAgency.padi,
  CertificationLevel? level = CertificationLevel.openWater,
  List<CertificationCredential> extra = const [],
  DateTime? issued,
  DateTime? expires,
}) => Certification(
  id: id,
  name: id,
  agency: agency.name,
  level: level?.name,
  additionalCredentials: extra,
  issueDate: issued,
  expiryDate: expires,
  createdAt: _t0,
  updatedAt: _t0,
);

CurrencyRule rule(
  String id, {
  CurrencyClockKind clock = CurrencyClockKind.activity,
  List<CertificationAgency> agencies = const [],
  List<CertificationLevel> levels = const [],
  int lapse = 365,
  int lead = 185,
  List<String> types = const [],
  List<DiveMode> modes = const [],
  bool builtIn = true,
  String? supersedes,
}) => CurrencyRule(
  id: id,
  name: id,
  clockKind: clock,
  agencies: agencies,
  levels: levels,
  lapseDays: lapse,
  leadDays: lead,
  countedDiveTypeIds: types,
  countedDiveModes: modes,
  isBuiltIn: builtIn,
  supersedesRuleId: supersedes,
  createdAt: _t0,
  updatedAt: _t0,
);

CurrencyPref pref(
  String certId,
  String ruleId, {
  bool muted = false,
  int? lapse,
  int? lead,
  List<String>? types,
  List<DiveMode>? modes,
}) => CurrencyPref(
  id: '$certId-$ruleId',
  certificationId: certId,
  ruleId: ruleId,
  muted: muted,
  lapseDaysOverride: lapse,
  leadDaysOverride: lead,
  countedDiveTypeIds: types,
  countedDiveModes: modes,
  createdAt: _t0,
  updatedAt: _t0,
);

CurrencyEvent event(String certId, DateTime date, {String? ruleId}) =>
    CurrencyEvent(
      id: 'e-$certId-${date.toIso8601String()}',
      certificationId: certId,
      ruleId: ruleId,
      eventType: CurrencyEventType.refresher,
      eventDate: date,
      createdAt: _t0,
      updatedAt: _t0,
    );

List<CredentialCurrency> run({
  required List<Certification> certs,
  required List<CurrencyRule> rules,
  List<CurrencyPref> prefs = const [],
  List<CurrencyEvent> events = const [],
  DiveActivityIndex activity = DiveActivityIndex.empty,
  required DateTime now,
}) => evaluateCurrency(
  certifications: certs,
  rules: rules,
  prefs: prefs,
  events: events,
  activity: activity,
  now: now,
);

void main() {
  final padiRefresher = rule(
    'padi_reactivate',
    agencies: const [CertificationAgency.padi],
    levels: const [
      CertificationLevel.openWater,
      CertificationLevel.advancedOpenWater,
      CertificationLevel.rescue,
    ],
  );

  group('calendar days', () {
    test('adding days across a DST change keeps the calendar date', () {
      // 2026-03-08 is the US spring-forward Sunday. Duration arithmetic
      // lands on 23:00 the day before in a DST zone; this must not.
      final day = addCalendarDays(DateTime(2026, 3, 1), 7);
      expect(day, DateTime(2026, 3, 8));
    });

    test('a UTC-flagged wall clock keeps its own day', () {
      expect(
        calendarDay(DateTime.utc(2026, 5, 4, 23, 55)),
        DateTime(2026, 5, 4),
      );
    });
  });

  group('matching', () {
    test('matches across credentials, including a dual-agency card', () {
      final card = cert(
        'n1',
        agency: CertificationAgency.ffessm,
        level: CertificationLevel.ffessmN1,
        extra: [
          CertificationCredential(
            agency: CertificationAgency.cmas.name,
            level: CertificationLevel.cmas1StarDiver.name,
          ),
        ],
      );
      final cmasRule = rule(
        'cmas_only',
        agencies: const [CertificationAgency.cmas],
        levels: const [CertificationLevel.cmas1StarDiver],
      );
      final statuses = run(
        certs: [card],
        rules: [cmasRule],
        activity: DiveActivityIndex(lastDiveAt: DateTime(2025, 12, 1)),
        now: DateTime(2026, 1, 1),
      );
      expect(statuses.single.rule.id, 'cmas_only');
    });

    test(
      'a card matching a rule through two credentials yields one status',
      () {
        final card = cert(
          'c',
          extra: [
            CertificationCredential(
              agency: CertificationAgency.padi.name,
              level: CertificationLevel.advancedOpenWater.name,
            ),
          ],
        );
        final statuses = run(
          certs: [card],
          rules: [padiRefresher],
          activity: DiveActivityIndex(lastDiveAt: DateTime(2025, 12, 1)),
          now: DateTime(2026, 1, 1),
        );
        expect(statuses, hasLength(1));
      },
    );

    test('a levelled rule never matches a card with no level', () {
      final statuses = run(
        certs: [cert('c', level: null)],
        rules: [padiRefresher],
        activity: DiveActivityIndex(lastDiveAt: DateTime(2025, 1, 1)),
        now: DateTime(2026, 1, 1),
      );
      expect(statuses, isEmpty);
    });
  });

  group('activity clock', () {
    test('no dives and no dates means no warning, only a neutral row', () {
      // The row stays on the detail page so its mapping can still be
      // changed, but it never warns and never counts for the chip.
      final s = run(
        certs: [cert('c')],
        rules: [padiRefresher],
        now: DateTime(2026),
      ).single;
      expect(s.origin, CurrencyAnchorOrigin.noCountedDive);
      expect(s.severity, CurrencySeverity.current);
      expect(s.needsAttention, isFalse);
      expect(s.hardened, isFalse);
    });

    test('a mapping no logged dive matches gives the neutral row', () {
      final s = run(
        certs: [cert('c')],
        rules: [padiRefresher],
        prefs: [
          pref('c', 'padi_reactivate', modes: const [DiveMode.ccr]),
        ],
        activity: DiveActivityIndex(lastDiveAt: DateTime(2020, 1, 1)),
        now: DateTime(2026),
      ).single;
      expect(s.origin, CurrencyAnchorOrigin.noCountedDive);
      expect(s.needsAttention, isFalse);
    });

    test('neutral rows sort after every row with a clock', () {
      final cave = rule(
        'cave',
        levels: const [CertificationLevel.cave],
        lapse: 365,
        lead: 90,
        types: const ['cave'],
      );
      final groups = collapseCurrency(
        run(
          certs: [cert('fc', level: CertificationLevel.cave)],
          rules: [
            cave,
            rule('any_cave', levels: const [CertificationLevel.cave]),
          ],
          activity: DiveActivityIndex(lastDiveAt: DateTime(2025, 12, 1)),
          now: DateTime(2026),
        ),
      );
      expect(groups.map((g) => g.representative.rule.id), ['any_cave', 'cave']);
    });

    test('severity at the threshold and one day either side', () {
      // Last dive 2025-01-01, lapse 365 days: due 2026-01-01. Lead 185
      // turns it due soon on 2025-06-30.
      final activity = DiveActivityIndex(lastDiveAt: DateTime(2025, 1, 1));
      CurrencySeverity at(DateTime now) => run(
        certs: [cert('c')],
        rules: [padiRefresher],
        activity: activity,
        now: now,
      ).single.severity;

      expect(at(DateTime(2025, 6, 29)), CurrencySeverity.current);
      expect(at(DateTime(2025, 6, 30)), CurrencySeverity.dueSoon);
      expect(at(DateTime(2025, 12, 31)), CurrencySeverity.dueSoon);
      expect(at(DateTime(2026, 1, 1)), CurrencySeverity.lapsed);
      expect(at(DateTime(2026, 1, 2)), CurrencySeverity.lapsed);
    });

    test('the anchor is the last dive, and due is anchor plus lapse', () {
      final s = run(
        certs: [cert('c')],
        rules: [padiRefresher],
        activity: DiveActivityIndex(lastDiveAt: DateTime(2025, 3, 4)),
        now: DateTime(2025, 4, 1),
      ).single;
      expect(s.origin, CurrencyAnchorOrigin.lastDive);
      expect(s.anchor, DateTime(2025, 3, 4));
      expect(s.dueDate, DateTime(2026, 3, 4));
    });

    test('a later refresher resets the clock without diving', () {
      final s = run(
        certs: [cert('c')],
        rules: [padiRefresher],
        events: [event('c', DateTime(2026, 2, 1), ruleId: 'padi_reactivate')],
        activity: DiveActivityIndex(lastDiveAt: DateTime(2024, 1, 1)),
        now: DateTime(2026, 3, 1),
      ).single;
      expect(s.origin, CurrencyAnchorOrigin.ledgerEvent);
      expect(s.severity, CurrencySeverity.current);
    });

    test('a refresher on one card resets the rule on every card', () {
      final statuses = run(
        certs: [
          cert('ow'),
          cert('aow', level: CertificationLevel.advancedOpenWater),
        ],
        rules: [padiRefresher],
        events: [event('ow', DateTime(2026, 2, 1), ruleId: 'padi_reactivate')],
        activity: DiveActivityIndex(lastDiveAt: DateTime(2024, 1, 1)),
        now: DateTime(2026, 3, 1),
      );
      expect(
        statuses.map((s) => s.origin),
        everyElement(CurrencyAnchorOrigin.ledgerEvent),
      );
    });

    test('a discipline rule counts only qualifying dives', () {
      final cave = rule(
        'cave_currency',
        levels: const [CertificationLevel.cave],
        lapse: 365,
        lead: 90,
        types: const ['cave', 'cavern'],
      );
      final s = run(
        certs: [cert('fc', level: CertificationLevel.cave)],
        rules: [cave],
        activity: DiveActivityIndex(
          lastDiveAt: DateTime(2026, 2, 1),
          lastDiveByTypeId: {'cavern': DateTime(2024, 6, 1)},
        ),
        now: DateTime(2026, 3, 1),
      ).single;
      expect(s.origin, CurrencyAnchorOrigin.lastQualifyingDive);
      expect(s.anchor, DateTime(2024, 6, 1));
      expect(s.severity, CurrencySeverity.lapsed);
    });

    test('a pref mapping replaces the rule mapping; [] means any dive', () {
      final cave = rule(
        'cave',
        levels: const [CertificationLevel.cave],
        types: const ['cave'],
      );
      final s = run(
        certs: [cert('fc', level: CertificationLevel.cave)],
        rules: [cave],
        prefs: [pref('fc', 'cave', types: const [], modes: const [])],
        activity: DiveActivityIndex(lastDiveAt: DateTime(2026, 2, 1)),
        now: DateTime(2026, 3, 1),
      ).single;
      expect(s.origin, CurrencyAnchorOrigin.lastDive);
    });

    test('types and modes together qualify a dive with either', () {
      final mixed = rule(
        'mixed',
        types: const ['technical'],
        modes: const [DiveMode.ccr],
      );
      final s = run(
        certs: [cert('c')],
        rules: [mixed],
        activity: DiveActivityIndex(
          lastDiveAt: DateTime(2026, 2, 1),
          lastDiveByTypeId: {'technical': DateTime(2025, 1, 1)},
          lastDiveByMode: {DiveMode.ccr: DateTime(2025, 9, 1)},
        ),
        now: DateTime(2026, 3, 1),
      ).single;
      expect(s.anchor, DateTime(2025, 9, 1));
    });

    test('a future anchor reads current', () {
      final s = run(
        certs: [cert('c')],
        rules: [padiRefresher],
        activity: DiveActivityIndex(lastDiveAt: DateTime(2027, 1, 1)),
        now: DateTime(2026, 1, 1),
      ).single;
      expect(s.severity, CurrencySeverity.current);
    });
  });

  group('date clock', () {
    final firstAid = rule(
      'first_aid_24mo',
      clock: CurrencyClockKind.date,
      levels: const [CertificationLevel.firstAid],
      lapse: 730,
      lead: 60,
    );

    test('card expiry is the due date', () {
      final s = run(
        certs: [
          cert(
            'efr',
            level: CertificationLevel.firstAid,
            expires: DateTime(2026, 3, 1),
          ),
        ],
        rules: [firstAid],
        now: DateTime(2026, 1, 15),
      ).single;
      expect(s.origin, CurrencyAnchorOrigin.cardExpiry);
      expect(s.dueDate, DateTime(2026, 3, 1));
      expect(s.severity, CurrencySeverity.dueSoon);
    });

    test('a renewal logged after the expiry clears the lapse', () {
      final s = run(
        certs: [
          cert(
            'efr',
            level: CertificationLevel.firstAid,
            expires: DateTime(2025, 1, 1),
          ),
        ],
        rules: [firstAid],
        events: [event('efr', DateTime(2025, 6, 1), ruleId: 'first_aid_24mo')],
        now: DateTime(2026, 1, 1),
      ).single;
      expect(s.origin, CurrencyAnchorOrigin.ledgerEvent);
      expect(s.dueDate, DateTime(2027, 6, 1));
      expect(s.severity, CurrencySeverity.current);
    });

    test('issue date plus the interval when nothing else exists', () {
      final s = run(
        certs: [
          cert(
            'efr',
            level: CertificationLevel.firstAid,
            issued: DateTime(2024, 1, 1),
          ),
        ],
        rules: [firstAid],
        now: DateTime(2026, 1, 2),
      ).single;
      expect(s.origin, CurrencyAnchorOrigin.cardIssue);
      expect(s.dueDate, DateTime(2025, 12, 31));
      expect(s.severity, CurrencySeverity.lapsed);
    });

    test('an undated card with no event has no clock', () {
      expect(
        run(
          certs: [cert('efr', level: CertificationLevel.firstAid)],
          rules: [firstAid],
          now: DateTime(2026),
        ),
        isEmpty,
      );
    });

    test('a window straddling DST counts calendar days', () {
      // Due 2026-03-08 (spring forward in DST zones). The day before is
      // still due soon, the day itself is lapsed.
      final s = run(
        certs: [
          cert(
            'efr',
            level: CertificationLevel.firstAid,
            expires: DateTime(2026, 3, 8),
          ),
        ],
        rules: [firstAid],
        now: DateTime(2026, 3, 7, 23, 30),
      ).single;
      expect(s.severity, CurrencySeverity.dueSoon);
    });
  });

  group('card expiry fallback', () {
    test('a dated card no rule covers still warns 90 days out', () {
      final s = run(
        certs: [
          cert(
            'nx',
            level: CertificationLevel.nitrox,
            expires: DateTime(2026, 3, 1),
          ),
        ],
        rules: const [],
        now: DateTime(2026, 1, 15),
      ).single;
      expect(s.rule.id, kCardExpiryRuleId);
      expect(s.severity, CurrencySeverity.dueSoon);
      expect(s.hardened, isFalse, reason: 'due soon is never hardened');
    });

    test('a card a date rule already covers gets no second status', () {
      final statuses = run(
        certs: [
          cert(
            'efr',
            level: CertificationLevel.firstAid,
            expires: DateTime(2026, 3, 1),
          ),
        ],
        rules: [firstAidRule()],
        now: DateTime(2026, 1, 15),
      );
      expect(statuses.map((s) => s.rule.id), ['first_aid_24mo']);
    });
  });

  group('prefs, superseding, hardening', () {
    test('an interval override replaces the rule interval', () {
      final s = run(
        certs: [cert('c')],
        rules: [padiRefresher],
        prefs: [pref('c', 'padi_reactivate', lapse: 30, lead: 10)],
        activity: DiveActivityIndex(lastDiveAt: DateTime(2026, 1, 1)),
        now: DateTime(2026, 1, 25),
      ).single;
      expect(s.lapseDays, 30);
      expect(s.severity, CurrencySeverity.dueSoon);
    });

    test(
      'a muted status is still returned, flagged, and never needs attention',
      () {
        final s = run(
          certs: [cert('c')],
          rules: [padiRefresher],
          prefs: [pref('c', 'padi_reactivate', muted: true)],
          activity: DiveActivityIndex(lastDiveAt: DateTime(2020, 1, 1)),
          now: DateTime(2026, 1, 1),
        ).single;
        expect(s.muted, isTrue);
        expect(s.severity, CurrencySeverity.lapsed);
        expect(s.needsAttention, isFalse);
      },
    );

    test('a live custom rule supersedes its built-in', () {
      final custom = rule(
        'mine',
        agencies: const [CertificationAgency.padi],
        lapse: 200,
        builtIn: false,
        supersedes: 'padi_reactivate',
      );
      final statuses = run(
        certs: [cert('c')],
        rules: [padiRefresher, custom],
        activity: DiveActivityIndex(lastDiveAt: DateTime(2025, 12, 1)),
        now: DateTime(2026, 1, 1),
      );
      expect(statuses.map((s) => s.rule.id), ['mine']);
    });

    test('only a lapse on a date the diver entered is hardened', () {
      final expiredCard = run(
        certs: [
          cert(
            'nx',
            level: CertificationLevel.nitrox,
            expires: DateTime(2025, 1, 1),
          ),
        ],
        rules: const [],
        now: DateTime(2026, 1, 1),
      ).single;
      expect(expiredCard.hardened, isTrue);

      final staleDiver = run(
        certs: [cert('c')],
        rules: [padiRefresher],
        activity: DiveActivityIndex(lastDiveAt: DateTime(2020, 1, 1)),
        now: DateTime(2026, 1, 1),
      ).single;
      expect(staleDiver.hardened, isFalse);
    });
  });

  group('final review fixes', () {
    test("another diver's refresher never resets this diver's rule", () {
      // Events on a certification that is not being evaluated (another
      // diver's card in the same library) must not count.
      final s = run(
        certs: [cert('mine')],
        rules: [padiRefresher],
        events: [
          event('theirs', DateTime(2026, 2, 1), ruleId: 'padi_reactivate'),
        ],
        activity: DiveActivityIndex(lastDiveAt: DateTime(2024, 1, 1)),
        now: DateTime(2026, 3, 1),
      ).single;
      expect(s.origin, CurrencyAnchorOrigin.lastDive);
      expect(s.severity, CurrencySeverity.lapsed);
    });

    final mine = rule(
      'mine',
      agencies: const [CertificationAgency.padi],
      lapse: 200,
      lead: 30,
      builtIn: false,
      supersedes: 'padi_reactivate',
    );

    test('a superseding rule keeps the mute set on the built-in', () {
      final s = run(
        certs: [cert('c')],
        rules: [padiRefresher, mine],
        prefs: [pref('c', 'padi_reactivate', muted: true)],
        activity: DiveActivityIndex(lastDiveAt: DateTime(2020, 1, 1)),
        now: DateTime(2026, 1, 1),
      ).single;
      expect(s.rule.id, 'mine');
      expect(s.muted, isTrue);
    });

    test("a superseding rule's own pref wins over the built-in's", () {
      final s = run(
        certs: [cert('c')],
        rules: [padiRefresher, mine],
        prefs: [pref('c', 'padi_reactivate', muted: true), pref('c', 'mine')],
        activity: DiveActivityIndex(lastDiveAt: DateTime(2020, 1, 1)),
        now: DateTime(2026, 1, 1),
      ).single;
      expect(s.muted, isFalse);
    });

    test(
      'a superseding rule counts refreshers logged against the built-in',
      () {
        final s = run(
          certs: [cert('c')],
          rules: [padiRefresher, mine],
          events: [
            event('c', DateTime(2025, 12, 1), ruleId: 'padi_reactivate'),
          ],
          activity: DiveActivityIndex(lastDiveAt: DateTime(2020, 1, 1)),
          now: DateTime(2026, 1, 1),
        ).single;
        expect(s.origin, CurrencyAnchorOrigin.ledgerEvent);
        expect(s.severity, CurrencySeverity.current);
      },
    );

    test('a rule whose scope this build cannot read matches nothing', () {
      final unreadable = rule(
        'future',
        agencies: const [],
      ).copyWith(unreadableScope: true);
      expect(
        run(
          certs: [cert('c')],
          rules: [unreadable],
          activity: DiveActivityIndex(lastDiveAt: DateTime(2020, 1, 1)),
          now: DateTime(2026, 1, 1),
        ),
        isEmpty,
      );
    });

    test('an unreadable custom copy does not hide its built-in', () {
      final copy = rule(
        'future_copy',
        builtIn: false,
        supersedes: 'padi_reactivate',
      ).copyWith(unreadableScope: true);
      final s = run(
        certs: [cert('c')],
        rules: [padiRefresher, copy],
        activity: DiveActivityIndex(lastDiveAt: DateTime(2020, 1, 1)),
        now: DateTime(2026, 1, 1),
      ).single;
      expect(s.rule.id, 'padi_reactivate');
    });

    test('a card expiry event never moves the due date', () {
      // The synthesized card-expiry status follows the printed date alone;
      // a renewed card is a new expiry date on the card.
      final s = run(
        certs: [
          cert(
            'nx',
            level: CertificationLevel.nitrox,
            expires: DateTime(2025, 1, 1),
          ),
        ],
        rules: const [],
        events: [event('nx', DateTime(2025, 6, 1), ruleId: kCardExpiryRuleId)],
        now: DateTime(2026, 1, 1),
      ).single;
      expect(s.origin, CurrencyAnchorOrigin.cardExpiry);
      expect(s.dueDate, DateTime(2025, 1, 1));
    });
  });

  group('collapsing and ordering', () {
    test(
      'cards sharing a rule and an anchor collapse to the most advanced',
      () {
        final groups = collapseCurrency(
          run(
            certs: [
              cert('ow', issued: DateTime(2010)),
              cert(
                'res',
                level: CertificationLevel.rescue,
                issued: DateTime(2014),
              ),
              cert(
                'aow',
                level: CertificationLevel.advancedOpenWater,
                issued: DateTime(2012),
              ),
            ],
            rules: [padiRefresher],
            activity: DiveActivityIndex(lastDiveAt: DateTime(2025, 1, 1)),
            now: DateTime(2026, 1, 1),
          ),
        );
        expect(groups, hasLength(1));
        expect(groups.single.representative.certification.id, 'res');
        expect(groups.single.members.map((m) => m.certification.id).toSet(), {
          'ow',
          'aow',
          'res',
        });
      },
    );

    test('severity first, then soonest due, muted last', () {
      final groups = collapseCurrency(
        run(
          certs: [
            cert(
              'a',
              level: CertificationLevel.nitrox,
              expires: DateTime(2026, 3, 1),
            ),
            cert(
              'b',
              level: CertificationLevel.nitrox,
              expires: DateTime(2026, 2, 1),
            ),
            cert(
              'c',
              level: CertificationLevel.nitrox,
              expires: DateTime(2025, 6, 1),
            ),
            cert(
              'd',
              level: CertificationLevel.nitrox,
              expires: DateTime(2025, 1, 1),
            ),
          ],
          rules: const [],
          prefs: [pref('d', kCardExpiryRuleId, muted: true)],
          now: DateTime(2026, 1, 15),
        ),
      );
      expect(groups.map((g) => g.representative.certification.id), [
        'c',
        'b',
        'a',
        'd',
      ]);
    });
  });
}

CurrencyRule firstAidRule() => rule(
  'first_aid_24mo',
  clock: CurrencyClockKind.date,
  levels: const [CertificationLevel.firstAid],
  lapse: 730,
  lead: 60,
);
