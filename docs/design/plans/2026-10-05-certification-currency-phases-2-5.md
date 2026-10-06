# Certification Currency Phases 2 to 5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the phase 1 data layer into the user-facing feature: a pure currency engine, the home strip chip that folds in the old expiring-certifications chip and opens a filtered certification list, a Currency section on the certification detail page, and a Settings Manage page for the rule catalog.

**Architecture:** A pure, total engine (`evaluateCurrency`, `collapseCurrency`) over certifications, rules, prefs, events and a `DiveActivityIndex` built from three `GROUP BY` aggregates. Riverpod providers feed it and catch their own failures, so a currency bug costs only the currency chip. The UI layers (chip, list scope, detail section, Manage page) only read providers and write through `CertificationCurrencyRepository`.

**Tech Stack:** Flutter, Riverpod (hand-written providers, `ref.invalidateSelfWhen`), Drift (in-memory SQLite in tests), `flutter gen-l10n` with 11 ARB locales, `flutter_test`.

**Spec:** `docs/design/specs/2026-09-22-certification-currency-design.md`. Phase 1 plan: `docs/design/plans/2026-09-22-certification-currency-phase1-data-and-sync.md` (implemented on this branch).

## Global Constraints

- Worktree root `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/build-feature-2267-788b28`, branch `ericgriffin/build-feature-2267-788b28`. Run every command from there.
- One PR for phases 1 to 5; its body says `Closes #2267`.
- No rule text ever says "required". Advisory wording names the agency's guidance.
- Elapsed time is calendar-day arithmetic, built with `DateTime(y, m, d + n)`, never `Duration` arithmetic and never `Duration.inDays`.
- Dive timestamps are wall-clock UTC (`DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)`); their calendar day is `DateTime(t.year, t.month, t.day)` from those components, exactly as `daysSinceLastDiveProvider` reads them. Certification and event dates are local `DateTime`s; their day is built the same way.
- Colours come from `StatusColors.of(context)` (`alert`, `warn`, `ok` swatches), never `Colors.*`.
- `ListTile.trailing` holds only fixed-width widgets (IconButton, PopupMenuButton, Icon, Switch, Checkbox). Text actions go in the subtitle as `TileSubtitleAction`.
- Dates render through `UnitFormatter(ref.watch(settingsProvider)).formatDate(...)`, embedded in an ARB placeholder for sentences.
- Numeric form fields use `numberValidator` / `readNumber` from `lib/shared/widgets/forms/`, never `int.tryParse` in form code.
- Every provider that reads a repository calls `ref.invalidateSelfWhen(repo.watchXChanges())`.
- New user-visible strings land in all 11 ARB files (ar, de, en, es, fr, he, hu, it, nl, pt, zh); only `app_en.arb` carries `@` metadata. Plural forms in fr and pt spell the count with the placeholder. Run `flutter gen-l10n` and commit the 11 ARBs with the 12 generated files.
- Manage page convention: lower-right extended FAB, inline edit and delete icons, no app-bar plus button, no row overflow menu.
- Every new chip destination goes in `test/core/router/app_router_test.dart`'s chip-destination list; every new route gets a builder test there.
- `dart format .`, `flutter analyze` (never piped), the touched tests, and `test/architecture/` after adding files under `lib/`, before each commit. Stage explicit paths.
- No em-dashes, no en-dash or double-hyphen punctuation, no emojis, no mention of the tooling anywhere.

## Decisions taken while planning (for review)

These fill gaps the spec leaves open. Each is called out in the task that implements it.

1. **Card expiry keeps warning.** The old chip warned for ANY card with an expiry date inside 90 days. No catalog rule covers, say, a nitrox card with an expiry date, so the engine synthesizes a `card_expiry` status (date clock on the card's `expiryDate`, lead 90 days) for every card with an expiry date that no other date rule already covers. It is not a database row; it is mutable per card through a pref keyed `card_expiry`, and its name is localized ("Card expiry").
2. **A renewal clears an expired card.** On a date clock the spec's anchor precedence is card expiry, then ledger event, then issue date plus interval. Read literally, logging a renewal after a card expired never clears the lapse until the diver edits the card. The plan uses the LATER of the card's expiry and the newest ledger event plus the interval when both exist, reporting whichever one won as the anchor origin.
3. **A refresher counts for the rule, not just the card.** On an activity clock, a ledger event for rule R on ANY of the diver's certifications resets R for every card it matches, because a ReActivate refreshes the diver, not one card. An event with no rule counts for every activity rule matching the card it was logged on. Date clocks use only that card's own events.
4. **Mapping union.** When both dive types and dive modes are counted, a dive qualifies if it carries any counted type OR any counted mode. The built-ins only ever set one of the two.
5. **Per card interval is a pref override.** The detail page's "edit interval" writes `lapse_days_override` / `lead_days_override` prefs (for every member of a collapsed row). Copy-on-write is the Manage page's job, where the rule itself is edited.
6. **Planned dives do not count.** The activity index skips `is_planned = 1` rows.
7. **Muted rows sort last** and never count toward the chip or the list scope.

## Review Focus

1. **A diver with many cards and no dives**: activity rules yield nothing, date rules only where a date exists; the chip must not appear for undated, unlogged cards (Task 1 test "no dives and no dates means no statuses").
2. **A forward-dated card or an anchor in the future** (device clock skew, a card typed with next year's date): reads `current`, never negative or lapsed (Task 1 test "a future anchor reads current").
3. **The currency provider throwing** (corrupt row, missing table): the home strip still renders the gear and flight-window chips; only the currency chip is absent (Task 3 test "a currency failure leaves the strip standing").
4. **Muting from a collapsed row**: OW + AOW + Rescue from one agency are one row; muting it must clear the chip, not leave two members still counting (Task 5 test "muting a collapsed row mutes every member").
5. **The list scope after the last attention item clears**: the filter indicator stays, the empty state says so and offers to clear, and the count subtitle reads "0 of N" (Task 4 test "an empty scope explains itself").

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/features/certifications/domain/entities/credential_currency.dart` (create) | `CurrencySeverity`, `CurrencyAnchorOrigin`, `CredentialCurrency`, `CurrencyGroup` |
| `lib/features/certifications/domain/entities/dive_activity_index.dart` (create) | `DiveActivityIndex` value: last dive, last dive per type id, per mode |
| `lib/features/certifications/domain/services/certification_currency_engine.dart` (create) | `evaluateCurrency`, `collapseCurrency`, `kCardExpiryRuleId`, ordering |
| `lib/features/certifications/domain/services/calendar_days.dart` (create) | `calendarDay`, `addCalendarDays` (the DST-safe arithmetic) |
| `lib/features/certifications/data/repositories/dive_activity_repository.dart` (create) | the three aggregates, its change stream |
| `lib/features/certifications/presentation/providers/certification_currency_providers.dart` (modify) | activity index, statuses, groups, attention summary, per card groups |
| `lib/features/certifications/presentation/currency_rule_display.dart` (create) | `builtInCurrencyRuleName`, `builtInCurrencyRuleAdvisory`, `currencyRuleName`, severity and event type labels |
| `lib/features/certifications/presentation/utils/currency_severity_colors.dart` (create) | severity to `StatusSwatch` |
| `lib/features/dashboard/presentation/providers/gauge_providers.dart` (modify) | `CurrencyGauge` in `DashboardGauges` |
| `lib/features/dashboard/presentation/widgets/gauge_strip.dart` (modify) | the folded chip, hardening |
| `lib/features/certifications/presentation/certification_attention_navigation.dart` (create) | `openCertificationsNeedingAttention` |
| `lib/features/certifications/presentation/providers/certification_query_providers.dart` (modify) | `certificationAttentionFilterProvider`, the narrowed list |
| `lib/features/certifications/presentation/providers/certification_list_count_provider.dart` (modify) | `isFiltered` includes the scope |
| `lib/features/certifications/presentation/widgets/certification_attention_filter_bar.dart` (create) | the visible, clearable indicator |
| `lib/features/certifications/presentation/widgets/certification_list_content.dart` (modify) | wraps the body with the bar, scoped empty state |
| `lib/features/certifications/presentation/widgets/certification_currency_section.dart` (create) | the detail Currency section |
| `lib/features/certifications/presentation/widgets/currency_event_dialog.dart` (create) | log a refresher, renewal or revalidation |
| `lib/features/certifications/presentation/widgets/currency_interval_dialog.dart` (create) | per card lapse and lead override |
| `lib/features/certifications/presentation/widgets/currency_mapping_dialog.dart` (create) | which dive types and modes count |
| `lib/features/certifications/presentation/pages/certification_detail_page.dart` (modify) | places the section after Dates |
| `lib/features/settings/presentation/pages/manage_currency_rules_page.dart` (create) | the catalog page |
| `lib/features/certifications/presentation/widgets/currency_rule_edit_dialog.dart` (create) | create, edit and copy-on-write |
| `lib/features/settings/presentation/pages/settings_page.dart` (modify) | the Manage tile |
| `lib/core/router/app_router.dart` (modify) | `/currency-rules` |
| `lib/l10n/arb/*.arb` (modify) and the 12 generated files | every new string |

---

### Task 1: Calendar arithmetic, entities and the engine

**Files:**
- Create: `lib/features/certifications/domain/services/calendar_days.dart`
- Create: `lib/features/certifications/domain/entities/dive_activity_index.dart`
- Create: `lib/features/certifications/domain/entities/credential_currency.dart`
- Create: `lib/features/certifications/domain/services/certification_currency_engine.dart`
- Test: `test/features/certifications/domain/certification_currency_engine_test.dart`

**Interfaces:**
- Consumes: `Certification` (`credentials`, `issueDate`, `expiryDate`), `CertificationLevelCatalog.ladderFor`, phase 1's `CurrencyRule`, `CurrencyPref`, `CurrencyEvent`.
- Produces:
  - `DateTime calendarDay(DateTime t)`, `DateTime addCalendarDays(DateTime day, int n)`, `int calendarDaysBetween(DateTime from, DateTime to)`.
  - `class DiveActivityIndex { DateTime? lastDiveAt; Map<String, DateTime> lastDiveByTypeId; Map<DiveMode, DateTime> lastDiveByMode; static const empty; }` (all values are calendar days).
  - `enum CurrencySeverity { current, dueSoon, lapsed }`, `enum CurrencyAnchorOrigin { cardExpiry, cardIssue, ledgerEvent, lastDive, lastQualifyingDive }`.
  - `class CredentialCurrency { Certification certification; CurrencyRule rule; CurrencySeverity severity; DateTime anchor; CurrencyAnchorOrigin origin; DateTime dueDate; int lapseDays; int leadDays; bool muted; CurrencyEventType? anchorEventType; bool get needsAttention; bool get hardened; }`.
  - `class CurrencyGroup { List<CredentialCurrency> members; CredentialCurrency get representative; ... same getters delegated }`.
  - `const kCardExpiryRuleId = 'card_expiry'`.
  - `List<CredentialCurrency> evaluateCurrency({required List<Certification> certifications, required List<CurrencyRule> rules, required List<CurrencyPref> prefs, required List<CurrencyEvent> events, required DiveActivityIndex activity, required DateTime now})`.
  - `List<CurrencyGroup> collapseCurrency(List<CredentialCurrency> statuses)`, already ordered.

- [ ] **Step 1: Write the failing engine test**

Create `test/features/certifications/domain/certification_currency_engine_test.dart`. The fixture helpers and every case:

```dart
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
  agency: agency,
  level: level,
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
      expect(calendarDaysBetween(DateTime(2026, 3, 1), DateTime(2026, 3, 8)), 7);
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
        extra: const [
          CertificationCredential(
            agency: CertificationAgency.cmas,
            level: CertificationLevel.cmas1StarDiver,
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

    test('a card matching a rule through two credentials yields one status', () {
      final card = cert(
        'c',
        extra: const [
          CertificationCredential(
            agency: CertificationAgency.padi,
            level: CertificationLevel.advancedOpenWater,
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
    });

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
    test('no dives and no dates means no statuses', () {
      expect(
        run(certs: [cert('c')], rules: [padiRefresher], now: DateTime(2026)),
        isEmpty,
      );
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
      final cave = rule('cave', levels: const [CertificationLevel.cave], types: const ['cave']);
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
          cert('efr', level: CertificationLevel.firstAid, expires: DateTime(2026, 3, 1)),
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
          cert('efr', level: CertificationLevel.firstAid, expires: DateTime(2025, 1, 1)),
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
          cert('efr', level: CertificationLevel.firstAid, issued: DateTime(2024, 1, 1)),
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
          cert('efr', level: CertificationLevel.firstAid, expires: DateTime(2026, 3, 8)),
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
          cert('nx', level: CertificationLevel.nitrox, expires: DateTime(2026, 3, 1)),
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
          cert('efr', level: CertificationLevel.firstAid, expires: DateTime(2026, 3, 1)),
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

    test('a muted status is still returned, flagged, and never needs attention', () {
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
    });

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
        certs: [cert('nx', level: CertificationLevel.nitrox, expires: DateTime(2025, 1, 1))],
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

  group('collapsing and ordering', () {
    test('cards sharing a rule and an anchor collapse to the most advanced', () {
      final groups = collapseCurrency(
        run(
          certs: [
            cert('ow', issued: DateTime(2010)),
            cert('res', level: CertificationLevel.rescue, issued: DateTime(2014)),
            cert('aow', level: CertificationLevel.advancedOpenWater, issued: DateTime(2012)),
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
    });

    test('severity first, then soonest due, muted last', () {
      final groups = collapseCurrency(
        run(
          certs: [
            cert('a', level: CertificationLevel.nitrox, expires: DateTime(2026, 3, 1)),
            cert('b', level: CertificationLevel.nitrox, expires: DateTime(2026, 2, 1)),
            cert('c', level: CertificationLevel.nitrox, expires: DateTime(2025, 6, 1)),
            cert('d', level: CertificationLevel.nitrox, expires: DateTime(2025, 1, 1)),
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
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/certifications/domain/certification_currency_engine_test.dart`
Expected: FAIL to compile; the engine files do not exist.

- [ ] **Step 3: Write the calendar helpers**

`lib/features/certifications/domain/services/calendar_days.dart`:

```dart
/// Calendar-day arithmetic for currency clocks (issue #2267).
///
/// Intervals here run from 30 to 1095 days, so a window straddling a local
/// DST transition is near certain. `Duration(days: n)` adds 24-hour blocks
/// and lands an hour off across one; these build dates from components.

/// The calendar day of [t], from its own components. A UTC-flagged dive
/// wall clock keeps its digits, exactly as daysSinceLastDiveProvider reads
/// it.
DateTime calendarDay(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime addCalendarDays(DateTime day, int n) =>
    DateTime(day.year, day.month, day.day + n);

/// Whole calendar days from [from] to [to]; negative when [to] is earlier.
/// Counted on UTC dates so no local offset change can shave an hour off.
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inHours ~/ 24;
}
```

- [ ] **Step 4: Write the two entity files**

`dive_activity_index.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// When the diver last dived, overall, per dive type and per dive mode, as
/// calendar days (issue #2267). Built from three GROUP BY aggregates, never
/// one query per certification.
class DiveActivityIndex extends Equatable {
  final DateTime? lastDiveAt;
  final Map<String, DateTime> lastDiveByTypeId;
  final Map<DiveMode, DateTime> lastDiveByMode;

  const DiveActivityIndex({
    this.lastDiveAt,
    this.lastDiveByTypeId = const {},
    this.lastDiveByMode = const {},
  });

  static const empty = DiveActivityIndex();

  @override
  List<Object?> get props => [lastDiveAt, lastDiveByTypeId, lastDiveByMode];
}
```

`credential_currency.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';

/// Deliberately not ServiceClockSeverity's names: gear "overdue" chips sit
/// on the same strip and in the same translation files.
enum CurrencySeverity { current, dueSoon, lapsed }

/// What a clock counts from, so every surface can explain itself.
enum CurrencyAnchorOrigin {
  cardExpiry,
  cardIssue,
  ledgerEvent,
  lastDive,
  lastQualifyingDive,
}

/// One rule evaluated against one certification.
class CredentialCurrency extends Equatable {
  final Certification certification;
  final CurrencyRule rule;
  final CurrencySeverity severity;

  /// The calendar day the clock counts from.
  final DateTime anchor;
  final CurrencyAnchorOrigin origin;

  /// The calendar day the rule lapses.
  final DateTime dueDate;
  final int lapseDays;
  final int leadDays;
  final bool muted;

  /// The event type when [origin] is [CurrencyAnchorOrigin.ledgerEvent].
  final CurrencyEventType? anchorEventType;

  const CredentialCurrency({
    required this.certification,
    required this.rule,
    required this.severity,
    required this.anchor,
    required this.origin,
    required this.dueDate,
    required this.lapseDays,
    required this.leadDays,
    this.muted = false,
    this.anchorEventType,
  });

  /// Lapsed or due soon, and not muted: what the chip and the list scope
  /// count.
  bool get needsAttention => !muted && severity != CurrencySeverity.current;

  /// Renders through the diver's hide: a lapse on a date the diver entered
  /// (a card expiry or a logged event). An inferred lapse stays hideable.
  bool get hardened =>
      !muted &&
      severity == CurrencySeverity.lapsed &&
      (origin == CurrencyAnchorOrigin.cardExpiry ||
          origin == CurrencyAnchorOrigin.ledgerEvent);

  @override
  List<Object?> get props => [
    certification.id,
    rule.id,
    severity,
    anchor,
    origin,
    dueDate,
    lapseDays,
    leadDays,
    muted,
    anchorEventType,
  ];
}

/// Statuses sharing a rule, an anchor and an interval, shown as one row.
/// OW, AOW and Rescue from one agency share the refresher rule and the last
/// dive, so the diver sees one row, not three.
class CurrencyGroup extends Equatable {
  /// Most advanced first; never empty.
  final List<CredentialCurrency> members;

  const CurrencyGroup(this.members);

  CredentialCurrency get representative => members.first;
  CurrencySeverity get severity => representative.severity;
  bool get needsAttention => representative.needsAttention;
  bool get hardened => representative.hardened;
  bool get muted => representative.muted;
  Set<String> get certificationIds => {
    for (final m in members) m.certification.id,
  };

  @override
  List<Object?> get props => [members];
}
```

- [ ] **Step 5: Write the engine**

`certification_currency_engine.dart`:

```dart
import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/credential_currency.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/domain/entities/dive_activity_index.dart';
import 'package:submersion/features/certifications/domain/services/calendar_days.dart';

/// The synthesized rule that keeps the old expiring-certifications warning
/// for a dated card no catalog rule covers. Not a database row; a pref keyed
/// by this id mutes or retunes it per card.
const kCardExpiryRuleId = 'card_expiry';

final _cardExpiryRule = CurrencyRule(
  id: kCardExpiryRuleId,
  name: 'Card expiry',
  clockKind: CurrencyClockKind.date,
  lapseDays: 0,
  leadDays: 90,
  isBuiltIn: true,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

/// Evaluates every rule against every certification (issue #2267). Pure and
/// total: no database, no clock read, nothing thrown.
List<CredentialCurrency> evaluateCurrency({
  required List<Certification> certifications,
  required List<CurrencyRule> rules,
  required List<CurrencyPref> prefs,
  required List<CurrencyEvent> events,
  required DiveActivityIndex activity,
  required DateTime now,
}) {
  final today = calendarDay(now);
  final superseded = {
    for (final r in rules)
      if (!r.isBuiltIn && r.supersedesRuleId != null) r.supersedesRuleId!,
  };
  final live = [
    for (final r in rules)
      if (!(r.isBuiltIn && superseded.contains(r.id))) r,
  ];
  final prefByKey = {for (final p in prefs) (p.certificationId, p.ruleId): p};

  final out = <CredentialCurrency>[];
  for (final cert in certifications) {
    final matched = [
      for (final r in live)
        if (cert.credentials.any((c) => _matches(r, c))) r,
    ];
    var dateCovered = false;
    for (final rule in matched) {
      final status = _evaluate(
        cert,
        rule,
        prefByKey[(cert.id, rule.id)],
        events,
        activity,
        today,
      );
      if (status == null) continue;
      if (rule.clockKind == CurrencyClockKind.date) dateCovered = true;
      out.add(status);
    }
    if (!dateCovered && cert.expiryDate != null) {
      final status = _evaluate(
        cert,
        _cardExpiryRule,
        prefByKey[(cert.id, kCardExpiryRuleId)],
        events,
        activity,
        today,
      );
      if (status != null) out.add(status);
    }
  }
  return out;
}

bool _matches(CurrencyRule rule, CertificationCredential c) {
  if (rule.agencies.isNotEmpty && !rule.agencies.contains(c.agency)) {
    return false;
  }
  if (rule.levels.isEmpty) return true;
  return c.level != null && rule.levels.contains(c.level);
}

CredentialCurrency? _evaluate(
  Certification cert,
  CurrencyRule rule,
  CurrencyPref? pref,
  List<CurrencyEvent> events,
  DiveActivityIndex activity,
  DateTime today,
) {
  final lapse = pref?.lapseDaysOverride ?? rule.lapseDays;
  final lead = pref?.leadDaysOverride ?? rule.leadDays;
  final muted = pref?.muted ?? false;

  final anchor = rule.clockKind == CurrencyClockKind.date
      ? _dateAnchor(cert, rule, events, lapse)
      : _activityAnchor(cert, rule, pref, events, activity, lapse);
  if (anchor == null) return null;

  final CurrencySeverity severity;
  if (!today.isBefore(anchor.due)) {
    severity = CurrencySeverity.lapsed;
  } else if (!today.isBefore(addCalendarDays(anchor.due, -lead))) {
    severity = CurrencySeverity.dueSoon;
  } else {
    severity = CurrencySeverity.current;
  }
  return CredentialCurrency(
    certification: cert,
    rule: rule,
    severity: severity,
    anchor: anchor.day,
    origin: anchor.origin,
    dueDate: anchor.due,
    lapseDays: lapse,
    leadDays: lead,
    muted: muted,
    anchorEventType: anchor.eventType,
  );
}

typedef _Anchor = ({
  DateTime day,
  DateTime due,
  CurrencyAnchorOrigin origin,
  CurrencyEventType? eventType,
});

/// Card expiry and the newest own event for the rule both count; the later
/// due date wins, so a renewal logged after an expiry clears the lapse.
/// The issue date plus the interval applies only when neither exists.
_Anchor? _dateAnchor(
  Certification cert,
  CurrencyRule rule,
  List<CurrencyEvent> events,
  int lapse,
) {
  final candidates = <_Anchor>[];
  final expiry = cert.expiryDate;
  if (expiry != null) {
    final day = calendarDay(expiry);
    candidates.add((
      day: day,
      due: day,
      origin: CurrencyAnchorOrigin.cardExpiry,
      eventType: null,
    ));
  }
  final own = _newest([
    for (final e in events)
      if (e.certificationId == cert.id && e.ruleId == rule.id) e,
  ]);
  if (own != null) {
    final day = calendarDay(own.eventDate);
    candidates.add((
      day: day,
      due: addCalendarDays(day, lapse),
      origin: CurrencyAnchorOrigin.ledgerEvent,
      eventType: own.eventType,
    ));
  }
  if (candidates.isEmpty && cert.issueDate != null) {
    final day = calendarDay(cert.issueDate!);
    candidates.add((
      day: day,
      due: addCalendarDays(day, lapse),
      origin: CurrencyAnchorOrigin.cardIssue,
      eventType: null,
    ));
  }
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => b.due.compareTo(a.due));
  return candidates.first;
}

/// The later of the last qualifying dive and the newest event that resets
/// the rule: one for this rule on any card, or a rule-less one on this card.
_Anchor? _activityAnchor(
  Certification cert,
  CurrencyRule rule,
  CurrencyPref? pref,
  List<CurrencyEvent> events,
  DiveActivityIndex activity,
  int lapse,
) {
  final types = pref?.countedDiveTypeIds ?? rule.countedDiveTypeIds;
  final modes = pref?.countedDiveModes ?? rule.countedDiveModes;
  final anyDive = types.isEmpty && modes.isEmpty;
  final DateTime? lastDive = anyDive
      ? activity.lastDiveAt
      : _latest([
          for (final t in types) activity.lastDiveByTypeId[t],
          for (final m in modes) activity.lastDiveByMode[m],
        ]);

  final event = _newest([
    for (final e in events)
      if (e.ruleId == rule.id ||
          (e.ruleId == null && e.certificationId == cert.id))
        e,
  ]);
  final eventDay = event == null ? null : calendarDay(event.eventDate);

  if (lastDive == null && eventDay == null) return null;
  if (eventDay != null && (lastDive == null || eventDay.isAfter(lastDive))) {
    return (
      day: eventDay,
      due: addCalendarDays(eventDay, lapse),
      origin: CurrencyAnchorOrigin.ledgerEvent,
      eventType: event!.eventType,
    );
  }
  final day = calendarDay(lastDive!);
  return (
    day: day,
    due: addCalendarDays(day, lapse),
    origin: anyDive
        ? CurrencyAnchorOrigin.lastDive
        : CurrencyAnchorOrigin.lastQualifyingDive,
    eventType: null,
  );
}

CurrencyEvent? _newest(List<CurrencyEvent> events) {
  if (events.isEmpty) return null;
  return events.reduce((a, b) => b.eventDate.isAfter(a.eventDate) ? b : a);
}

DateTime? _latest(Iterable<DateTime?> days) {
  DateTime? best;
  for (final d in days) {
    if (d != null && (best == null || d.isAfter(best))) best = d;
  }
  return best;
}

/// Groups [statuses] for display by rule, anchor, interval and mute, the
/// most advanced card first, and orders the groups: unmuted before muted,
/// then lapsed, due soon, current, then soonest due.
List<CurrencyGroup> collapseCurrency(List<CredentialCurrency> statuses) {
  final byKey = <Object, List<CredentialCurrency>>{};
  for (final s in statuses) {
    final key = (s.rule.id, s.anchor, s.origin, s.lapseDays, s.leadDays, s.muted);
    (byKey[key] ??= []).add(s);
  }
  final groups = [
    for (final members in byKey.values)
      CurrencyGroup([...members]..sort(_mostAdvancedFirst)),
  ];
  groups.sort(_groupOrder);
  return groups;
}

int _rank(Certification c) {
  final ladder = CertificationLevelCatalog.ladderFor(c.agency);
  return c.level == null ? -1 : ladder.indexOf(c.level!);
}

int _mostAdvancedFirst(CredentialCurrency a, CredentialCurrency b) {
  final byRank = _rank(b.certification).compareTo(_rank(a.certification));
  if (byRank != 0) return byRank;
  final ai = a.certification.issueDate;
  final bi = b.certification.issueDate;
  if (ai != bi) {
    if (ai == null) return 1;
    if (bi == null) return -1;
    return bi.compareTo(ai);
  }
  return a.certification.id.compareTo(b.certification.id);
}

int _groupOrder(CurrencyGroup a, CurrencyGroup b) {
  if (a.muted != b.muted) return a.muted ? 1 : -1;
  final bySeverity = b.severity.index.compareTo(a.severity.index);
  if (bySeverity != 0) return bySeverity;
  return a.representative.dueDate.compareTo(b.representative.dueDate);
}
```

- [ ] **Step 6: Run the engine test**

Run: `flutter test test/features/certifications/domain/certification_currency_engine_test.dart`
Expected: PASS, every case.

- [ ] **Step 7: Commit**

```bash
dart format .
flutter analyze
git add lib/features/certifications/domain test/features/certifications/domain/certification_currency_engine_test.dart
git commit -m "feat(certifications): certification currency engine"
```

---

### Task 2: Activity index and providers

**Files:**
- Create: `lib/features/certifications/data/repositories/dive_activity_repository.dart`
- Modify: `lib/features/certifications/presentation/providers/certification_currency_providers.dart`
- Test: `test/features/certifications/data/dive_activity_repository_test.dart`
- Test: `test/features/certifications/presentation/providers/certification_currency_status_providers_test.dart`

**Interfaces:**
- Consumes: Task 1's engine and entities; phase 1's rule, pref and event providers; `allCertificationsProvider`, `validatedCurrentDiverIdProvider`.
- Produces:
  - `class DiveActivityRepository { Future<DiveActivityIndex> buildIndex({String? diverId}); Stream<void> watchDiveChanges(); }`
  - `diveActivityIndexProvider: FutureProvider<DiveActivityIndex>`
  - `credentialCurrencyProvider: FutureProvider<List<CredentialCurrency>>` (uncollapsed; empty and logged on any failure)
  - `currencyGroupsProvider: FutureProvider<List<CurrencyGroup>>`
  - `class CurrencyAttention { int count; bool anyLapsed; bool anyHardened; Set<String> certificationIds; static const none; }`
  - `currencyAttentionProvider: FutureProvider<CurrencyAttention>`
  - `certificationCurrencyGroupsProvider: FutureProvider.family<List<CurrencyGroup>, String>` (groups whose members include the card, muted included)

- [ ] **Step 1: Write the failing repository test**

```dart
// test/features/certifications/data/dive_activity_repository_test.dart
// Seeds one diver, dives through DivesCompanion.insert with diveDateTime and
// entryTime as wall-clock-UTC millis, diveMode values, and dive_dive_types
// junction rows, then asserts:
test('the last dive overall, per type and per mode', ...);       // MAX per key
test('planned dives never count', ...);                          // is_planned = 1 ignored
test('another diver\'s dives never count', ...);                  // diver scope
test('entry time wins over the legacy date when both exist', ...);// COALESCE order
test('a dive at 23:55 keeps its own calendar day', ...);          // wall clock read
test('three statements whether one dive or fifty', () async {
  // NativeDatabase.memory(logStatements: true) with the print capture used
  // by the counting-queries tests; the count must be identical for 1 and 50
  // dives.
});
```

Each case inserts rows with explicit values, for example:

```dart
await db.into(db.dives).insert(
  DivesCompanion.insert(
    id: 'd1',
    diverId: const Value('me'),
    diveDateTime: DateTime.utc(2025, 3, 4, 10).millisecondsSinceEpoch,
    entryTime: Value(DateTime.utc(2025, 3, 4, 10).millisecondsSinceEpoch),
    diveMode: const Value('ccr'),
    createdAt: 0,
    updatedAt: 0,
  ),
);
await db.into(db.diveDiveTypes).insert(
  DiveDiveTypesCompanion.insert(id: 'j1', diveId: 'd1', diveTypeId: 'cave', createdAt: 0),
);
final index = await DiveActivityRepository().buildIndex(diverId: 'me');
expect(index.lastDiveAt, DateTime(2025, 3, 4));
expect(index.lastDiveByTypeId['cave'], DateTime(2025, 3, 4));
expect(index.lastDiveByMode[DiveMode.ccr], DateTime(2025, 3, 4));
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/certifications/data/dive_activity_repository_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Write the repository**

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/certifications/domain/entities/dive_activity_index.dart';
import 'package:submersion/features/certifications/domain/services/calendar_days.dart';

/// The three aggregates behind activity clocks (issue #2267). Dive times are
/// wall-clock UTC, read exactly as daysSinceLastDiveProvider reads them, so
/// the currency chip and the last-dive chip never disagree by a day.
class DiveActivityRepository {
  AppDatabase get _db => DatabaseService.instance.database;

  static const _when = 'COALESCE(d.entry_time, d.dive_date_time)';

  Stream<void> watchDiveChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.dives),
      TableUpdateQuery.onTable(_db.diveDiveTypes),
    ]),
  );

  Future<DiveActivityIndex> buildIndex({String? diverId}) async {
    final scope = diverId == null ? '' : 'AND d.diver_id = ?';
    final vars = [if (diverId != null) Variable.withString(diverId)];

    final last = await _db
        .customSelect(
          'SELECT MAX($_when) AS t FROM dives d WHERE d.is_planned = 0 $scope',
          variables: vars,
        )
        .getSingle();
    final byType = await _db
        .customSelect(
          'SELECT ddt.dive_type_id AS k, MAX($_when) AS t '
          'FROM dive_dive_types ddt JOIN dives d ON d.id = ddt.dive_id '
          'WHERE d.is_planned = 0 $scope GROUP BY ddt.dive_type_id',
          variables: vars,
        )
        .get();
    final byMode = await _db
        .customSelect(
          'SELECT d.dive_mode AS k, MAX($_when) AS t FROM dives d '
          'WHERE d.is_planned = 0 $scope GROUP BY d.dive_mode',
          variables: vars,
        )
        .get();

    return DiveActivityIndex(
      lastDiveAt: _day(last.read<int?>('t')),
      lastDiveByTypeId: {
        for (final r in byType)
          if (_day(r.read<int?>('t')) case final day?) r.read<String>('k'): day,
      },
      lastDiveByMode: {
        for (final r in byMode)
          if (_day(r.read<int?>('t')) case final day?)
            DiveMode.fromCode(r.read<String>('k')): day,
      },
    );
  }

  static DateTime? _day(int? ms) => ms == null
      ? null
      : calendarDay(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
}
```

- [ ] **Step 4: Run the repository test**

Expected: PASS.

- [ ] **Step 5: Write the failing provider test**

`test/features/certifications/presentation/providers/certification_currency_status_providers_test.dart`, a `ProviderContainer` with overrides of `allCertificationsProvider`, `currencyRulesProvider`, `currencyPrefsProvider`, `currencyEventsProvider` and `diveActivityIndexProvider`:

```dart
test('attention counts collapsed groups, not cards', ...);       // OW+AOW+Rescue lapsed -> count 1
test('muted groups never count', ...);
test('anyHardened only for an entered-date lapse', ...);
test('a currency failure returns empty, never throws', () async {
  // currencyRulesProvider overridden to throw StateError; the status and
  // attention providers resolve to [] and CurrencyAttention.none.
});
test('per card groups include every group the card is a member of', ...);
```

- [ ] **Step 6: Write the providers**

Append to `certification_currency_providers.dart`:

```dart
final diveActivityRepositoryProvider = Provider<DiveActivityRepository>(
  (ref) => DiveActivityRepository(),
);

final diveActivityIndexProvider = FutureProvider<DiveActivityIndex>((ref) async {
  final repository = ref.watch(diveActivityRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchDiveChanges());
  return repository.buildIndex(diverId: diverId);
});

/// Every status, uncollapsed. Catches its own failures: the home strip awaits
/// this inside dashboardGaugesProvider, and an uncaught throw would take the
/// whole strip, hardened safety chips included, to its retry chip.
final credentialCurrencyProvider = FutureProvider<List<CredentialCurrency>>((
  ref,
) async {
  try {
    return evaluateCurrency(
      certifications: await ref.watch(allCertificationsProvider.future),
      rules: await ref.watch(currencyRulesProvider.future),
      prefs: await ref.watch(currencyPrefsProvider.future),
      events: await ref.watch(currencyEventsProvider.future),
      activity: await ref.watch(diveActivityIndexProvider.future),
      now: DateTime.now(),
    );
  } catch (e, stackTrace) {
    _log.error(
      'Certification currency unavailable; the chip is hidden',
      error: e,
      stackTrace: stackTrace,
    );
    return const [];
  }
});

final currencyGroupsProvider = FutureProvider<List<CurrencyGroup>>(
  (ref) async => collapseCurrency(
    await ref.watch(credentialCurrencyProvider.future),
  ),
);

class CurrencyAttention {
  final int count;
  final bool anyLapsed;
  final bool anyHardened;
  final Set<String> certificationIds;

  const CurrencyAttention({
    this.count = 0,
    this.anyLapsed = false,
    this.anyHardened = false,
    this.certificationIds = const {},
  });

  static const none = CurrencyAttention();
}

final currencyAttentionProvider = FutureProvider<CurrencyAttention>((ref) async {
  final groups = [
    for (final g in await ref.watch(currencyGroupsProvider.future))
      if (g.needsAttention) g,
  ];
  return CurrencyAttention(
    count: groups.length,
    anyLapsed: groups.any((g) => g.severity == CurrencySeverity.lapsed),
    anyHardened: groups.any((g) => g.hardened),
    certificationIds: {for (final g in groups) ...g.certificationIds},
  );
});

final certificationCurrencyGroupsProvider =
    FutureProvider.family<List<CurrencyGroup>, String>((ref, certId) async {
      return [
        for (final g in await ref.watch(currencyGroupsProvider.future))
          if (g.certificationIds.contains(certId)) g,
      ];
    });
```

with `final _log = LoggerService.forClass(CertificationCurrencyRepository);` at the top of the file, and the imports for the engine, entities and repository.

- [ ] **Step 7: Run both tests and the architecture guards**

Run: `flutter test test/features/certifications test/architecture`
Expected: PASS. `provider_change_tick_test` sees the new repository-reading provider calling `invalidateSelfWhen`.

- [ ] **Step 8: Commit**

```bash
dart format .
flutter analyze
git add lib/features/certifications test/features/certifications
git commit -m "feat(certifications): activity index and currency providers"
```

---

### Task 3: Rule display and the home chip fold

**Files:**
- Create: `lib/features/certifications/presentation/currency_rule_display.dart`
- Create: `lib/features/certifications/presentation/utils/currency_severity_colors.dart`
- Create: `lib/features/certifications/presentation/certification_attention_navigation.dart`
- Modify: `lib/features/dashboard/presentation/providers/gauge_providers.dart`
- Modify: `lib/features/dashboard/presentation/widgets/gauge_strip.dart:290-301`
- Modify: `lib/features/settings/presentation/pages/home_appearance_page.dart` (label only, through the ARB value)
- Modify: 11 ARB files and the 12 generated localization files
- Test: `test/features/certifications/presentation/currency_rule_display_test.dart`
- Test: `test/features/dashboard/presentation/widgets/gauge_strip_test.dart` (extend)
- Test: `test/features/dashboard/presentation/providers/dashboard_gauges_provider_test.dart` (extend)

**Interfaces:**
- Consumes: `currencyAttentionProvider`, `CurrencyAttention`, `kCardExpiryRuleId`.
- Produces:
  - `String? builtInCurrencyRuleName(AppLocalizations l10n, String id)` and `String? builtInCurrencyRuleAdvisory(AppLocalizations l10n, String id)` (null for unknown ids)
  - `String currencyRuleName(AppLocalizations l10n, CurrencyRule rule)` (built-in translation, else the stored name)
  - `String? currencyRuleAdvisory(AppLocalizations l10n, CurrencyRule rule)`
  - `extension CurrencySeverityDisplay on CurrencySeverity { String label(AppLocalizations l10n); }`
  - `extension CurrencyEventTypeDisplay on CurrencyEventType { String label(AppLocalizations l10n); }`
  - `StatusSwatch? currencySeveritySwatch(StatusColors colors, CurrencySeverity severity)`
  - `void openCertificationsNeedingAttention(BuildContext context, WidgetRef ref)` (Task 4 supplies the provider it writes)
  - `DashboardGauges.certCurrency` (`CurrencyAttention`), replacing `expiringCertCount`

ARB keys added in this task (English shown; translate into the other ten):

| key | English |
| --- | --- |
| `currencyRule_padi_reactivate_name` | PADI refresher (ReActivate) |
| `currencyRule_ssi_skills_update_name` | SSI Scuba Skills Update |
| `currencyRule_generic_refresher_name` | Refresher |
| `currencyRule_first_aid_24mo_name` | First aid and CPR renewal |
| `currencyRule_pro_membership_annual_name` | Professional membership renewal |
| `currencyRule_gue_revalidation_name` | GUE revalidation |
| `currencyRule_ffessm_licence_annual_name` | FFESSM licence and medical certificate |
| `currencyRule_cave_currency_name` | Cave currency |
| `currencyRule_rebreather_currency_name` | Rebreather currency |
| `currencyRule_deco_currency_name` | Decompression currency |
| `currencyRule_card_expiry_name` | Card expiry |
| `currencyRule_padi_reactivate_advisory` | PADI suggests a ReActivate refresher after six to twelve months out of the water. |
| `currencyRule_ssi_skills_update_advisory` | SSI suggests a Scuba Skills Update after six to twelve months without diving. |
| `currencyRule_generic_refresher_advisory` | Most agencies suggest a refresher after six to twelve months without diving. |
| `currencyRule_first_aid_advisory` | First aid, CPR and oxygen provider credentials typically renew every two years. |
| `currencyRule_pro_membership_advisory` | Professional memberships typically renew every year to keep teaching status active. |
| `currencyRule_gue_revalidation_advisory` | GUE ratings are typically revalidated every three years. |
| `currencyRule_ffessm_licence_advisory` | The FFESSM licence and its medical certificate are renewed every year. |
| `currencyRule_cave_currency_advisory` | Cave skills fade without practice; a check-out dive is commonly advised after a year away. |
| `currencyRule_rebreather_currency_advisory` | Rebreather skills fade quickly; many agencies advise a refresher after six months away. |
| `currencyRule_deco_currency_advisory` | Decompression procedures are commonly refreshed after a year without a decompression dive. |
| `currencyRule_card_expiry_advisory` | The expiry date printed on this card. |
| `certifications_currency_status_current` | Current |
| `certifications_currency_status_dueSoon` | Due soon |
| `certifications_currency_status_lapsed` | Lapsed |
| `certifications_currency_eventType_refresher` | Refresher |
| `certifications_currency_eventType_renewal` | Renewal |
| `certifications_currency_eventType_revalidation` | Revalidation |
| `certifications_currency_eventType_skillsUpdate` | Skills update |
| `certifications_currency_eventType_other` | Other |
| `dashboard_gauges_certsNeedAttention` | `{count, plural, =1{{count} certification needs attention} other{{count} certifications need attention}}` |

`settings_homeChips_certifications` changes value from "Certification expiry" to "Certification currency" in all eleven files (same key, so the hide setting is untouched). `dashboard_gauges_certsExpiring` is removed from all eleven files once nothing uses it.

- [ ] **Step 1: Write the failing display test**

```dart
test('every seeded built-in id has a name and an advisory in English', () {
  for (final id in const [
    'padi_reactivate', 'ssi_skills_update', 'generic_refresher',
    'first_aid_24mo', 'pro_membership_annual', 'gue_revalidation',
    'ffessm_licence_annual', 'cave_currency', 'rebreather_currency',
    'deco_currency', 'card_expiry',
  ]) {
    expect(builtInCurrencyRuleName(en, id), isNotEmpty, reason: id);
    expect(builtInCurrencyRuleAdvisory(en, id), isNotEmpty, reason: id);
  }
});
test('no built-in advisory says required, in any locale', ...); // loop AppLocalizations.supportedLocales, lookupAppLocalizations, case-insensitive 'required'/'requis'/... not needed: assert English only, the wording rule is English-authored
test('a custom rule shows its own name and text, untranslated', ...);
test('an unknown id is null, so a rule from a newer build falls back', ...);
```

with `final en = lookupAppLocalizations(const Locale('en'));`.

- [ ] **Step 2: Add the ARB keys to all eleven locales, run `flutter gen-l10n`**

- [ ] **Step 3: Write `currency_rule_display.dart` and `currency_severity_colors.dart`**

```dart
String? builtInCurrencyRuleName(AppLocalizations l10n, String id) =>
    switch (id) {
      'padi_reactivate' => l10n.currencyRule_padi_reactivate_name,
      'ssi_skills_update' => l10n.currencyRule_ssi_skills_update_name,
      'generic_refresher' => l10n.currencyRule_generic_refresher_name,
      'first_aid_24mo' => l10n.currencyRule_first_aid_24mo_name,
      'pro_membership_annual' => l10n.currencyRule_pro_membership_annual_name,
      'gue_revalidation' => l10n.currencyRule_gue_revalidation_name,
      'ffessm_licence_annual' => l10n.currencyRule_ffessm_licence_annual_name,
      'cave_currency' => l10n.currencyRule_cave_currency_name,
      'rebreather_currency' => l10n.currencyRule_rebreather_currency_name,
      'deco_currency' => l10n.currencyRule_deco_currency_name,
      kCardExpiryRuleId => l10n.currencyRule_card_expiry_name,
      _ => null,
    };

String currencyRuleName(AppLocalizations l10n, CurrencyRule rule) =>
    (rule.isBuiltIn ? builtInCurrencyRuleName(l10n, rule.id) : null) ??
    rule.name;
```

`builtInCurrencyRuleAdvisory` is the same switch over the `_advisory` getters (`first_aid_24mo` maps to `currencyRule_first_aid_advisory`, matching the seeded `advisory_key`), and `currencyRuleAdvisory` returns `rule.advisoryText` for a custom rule. The colour helper mirrors `serviceSeveritySwatch`:

```dart
StatusSwatch? currencySeveritySwatch(StatusColors colors, CurrencySeverity s) =>
    switch (s) {
      CurrencySeverity.lapsed => colors.alert,
      CurrencySeverity.dueSoon => colors.warn,
      CurrencySeverity.current => null,
    };
```

- [ ] **Step 4: Run the display test**

Expected: PASS.

- [ ] **Step 5: Write the failing chip tests**

In `gauge_strip_test.dart`, replace the `expiringCertCount` cases with:

```dart
test('the certifications chip counts collapsed groups and opens the scope', ...);
// gauges with certCurrency: CurrencyAttention(count: 2, certificationIds: {'a','b'});
// label '2 certifications need attention', tone warn; tap -> spy.location
// '/certifications' and spy.container.read(certificationAttentionFilterProvider) == true
test('a lapse makes the chip alert-toned', ...);
test('no chip at zero', ...);
test('a hardened lapse renders through the hide', ...);   // allHidden() + anyHardened
test('an inferred lapse stays hideable', ...);            // allHidden() + anyLapsed only
```

and populate `certCurrency` in "every rendered chip is tappable". In `dashboard_gauges_provider_test.dart`, replace the `certCount` parameter with a `CurrencyAttention` override of `currencyAttentionProvider`, and add:

```dart
test('a currency failure leaves the strip standing', () async {
  // credentialCurrencyProvider's inputs overridden to throw; the gauges
  // future still resolves, with gear and flight-window data intact and
  // certCurrency == CurrencyAttention.none.
});
```

- [ ] **Step 6: Fold the chip**

In `gauge_providers.dart`, replace `final int expiringCertCount;` with `final CurrencyAttention certCurrency;` (default `CurrencyAttention.none`) and in `dashboardGaugesProvider` replace the `expiringCertificationCountProvider` read with `final certCurrency = await ref.watch(currencyAttentionProvider.future);`.

In `gauge_strip.dart`, replace the block at :290-301:

```dart
    final cert = g.certCurrency;
    // Hardened like gear, insurance and the flight window: a lapse on a date
    // the diver entered renders through the hide. An inferred lapse (no
    // dives, an issue date plus a catalog interval) stays hideable.
    if (cert.count > 0 &&
        (_shown(hidden, HomeChipType.certifications) || cert.anyHardened)) {
      chips.add(
        _chip(
          context,
          icon: Icons.card_membership_outlined,
          label: l10n.dashboard_gauges_certsNeedAttention(cert.count),
          tone: cert.anyLapsed ? _Tone.alert : _Tone.warn,
          onTap: () => openCertificationsNeedingAttention(context, ref),
        ),
      );
    }
```

`openCertificationsNeedingAttention` replaces the scope rather than merging it, then pushes, as `openEquipmentWithServiceDue` does:

```dart
void openCertificationsNeedingAttention(BuildContext context, WidgetRef ref) {
  ref.read(certificationQueryProvider.notifier).state = null;
  ref.read(certificationAttentionFilterProvider.notifier).state = true;
  context.push('/certifications');
}
```

- [ ] **Step 7: Run the dashboard tests and the router test**

Run: `flutter test test/features/dashboard test/core/router/app_router_test.dart`
Expected: PASS. `/certifications` is already in the chip-destination list.

- [ ] **Step 8: Commit**

```bash
dart format .
flutter analyze
git add lib/features/certifications/presentation lib/features/dashboard lib/l10n test/features/certifications/presentation test/features/dashboard
git commit -m "feat(certifications): fold currency into the home certifications chip"
```

(Task 3 and Task 4 land in one commit if the navigation helper's provider is created in Task 4 first; build Task 4 Step 3 before this task's Step 6.)

---

### Task 4: The needs-attention list scope

**Files:**
- Modify: `lib/features/certifications/presentation/providers/certification_query_providers.dart`
- Modify: `lib/features/certifications/presentation/providers/certification_list_count_provider.dart`
- Create: `lib/features/certifications/presentation/widgets/certification_attention_filter_bar.dart`
- Modify: `lib/features/certifications/presentation/widgets/certification_list_content.dart` (`_withQueryChips` :166, `_buildEmptyState` :706)
- Modify: ARB files (`certifications_list_filter_needsAttention` "Needs attention", `certifications_list_filter_clear` "Clear", `certifications_list_needsAttention_empty` "No certifications need attention", `certifications_list_needsAttention_emptySubtitle` "Every certification is current or muted.")
- Test: `test/features/certifications/presentation/widgets/certification_attention_scope_test.dart`

**Interfaces:**
- Consumes: `currencyAttentionProvider`.
- Produces: `certificationAttentionFilterProvider: StateProvider<bool>` (default false).

- [ ] **Step 1: Write the failing widget test**

```dart
testWidgets('the scope shows only certifications needing attention', ...);
testWidgets('the indicator is visible and clears the scope', ...);   // InputChip delete -> provider false, all rows back
testWidgets('the count subtitle reads shown of total', ...);         // '1 of 3'
testWidgets('an empty scope explains itself', ...);                  // empty text + clear action, subtitle '0 of 3'
testWidgets('the scope and a query narrow together', ...);
```

Overrides: `certificationListNotifierProvider` seeded with three certifications, `currencyAttentionProvider` with `CurrencyAttention(count: 1, certificationIds: {'b'})`.

- [ ] **Step 2: Add the provider and narrow the list**

```dart
/// The home chip's "needs attention" scope (issue #2267). Real filter state
/// with a visible, clearable indicator, so a short list is never a mystery.
final certificationAttentionFilterProvider = StateProvider<bool>((ref) => false);

final filteredCertificationsProvider = Provider<AsyncValue<List<Certification>>>(
  (ref) {
    final byQuery = narrowByQuery(
      ref,
      ref.watch(certificationListNotifierProvider),
      certificationQueryEntity,
      ref.watch(certificationQueryProvider),
      (c) => c.id,
    );
    if (!ref.watch(certificationAttentionFilterProvider)) return byQuery;
    final ids =
        ref.watch(currencyAttentionProvider).value?.certificationIds ?? const {};
    return byQuery.whenData(
      (certs) => [for (final c in certs) if (ids.contains(c.id)) c],
    );
  },
);
```

and in the count provider: `isFiltered: ref.watch(certificationQueryProvider) != null || ref.watch(certificationAttentionFilterProvider)`.

- [ ] **Step 3: Write the bar and wire it into the list**

`CertificationAttentionFilterBar` follows equipment's `_buildActiveFiltersBar`: a `Container` tinted `surfaceContainerHighest` at alpha 0.5 with an `outlineVariant` bottom border, holding one `InputChip(label: Text(l10n.certifications_list_filter_needsAttention), onDeleted: () => ref.read(certificationAttentionFilterProvider.notifier).state = false)`. In `_withQueryChips`, when the scope is on, return `Column(children: [const CertificationAttentionFilterBar(), Expanded(child: framed)])`, so all three layouts carry it. `_buildEmptyState` checks the scope before the query: when on, the empty text and subtitle above plus a `TextButton` that clears it.

- [ ] **Step 4: Run the test**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/features/certifications lib/l10n test/features/certifications
git commit -m "feat(certifications): needs-attention scope on the certification list"
```

---

### Task 5: Certification detail Currency section

**Files:**
- Create: `lib/features/certifications/presentation/widgets/certification_currency_section.dart`
- Create: `lib/features/certifications/presentation/widgets/currency_event_dialog.dart`
- Create: `lib/features/certifications/presentation/widgets/currency_interval_dialog.dart`
- Create: `lib/features/certifications/presentation/widgets/currency_mapping_dialog.dart`
- Modify: `lib/features/certifications/presentation/pages/certification_detail_page.dart:148`
- Modify: ARB files
- Test: `test/features/certifications/presentation/widgets/certification_currency_section_test.dart`

**Interfaces:**
- Consumes: `certificationCurrencyGroupsProvider(certId)`, `certificationCurrencyEventsProvider(certId)`, `certificationCurrencyRepositoryProvider`, `currencyRuleName`, `currencyRuleAdvisory`, the severity and event type labels, `currencySeveritySwatch`, `DiveTypeMultiSelectField`, `DiveModeDisplay.localizedName`, `showAppDatePicker`, `numberValidator`, `readNumber`, `TileSubtitleAction`.
- Produces: `CertificationCurrencySection({required Certification certification})`.

ARB keys (English):

| key | English |
| --- | --- |
| `certifications_detail_sectionTitle_currency` | Currency |
| `certifications_currency_dueOn` | Due {date} |
| `certifications_currency_lapsedSince` | Lapsed since {date} |
| `certifications_currency_anchor_lastDive` | Last dive {date} |
| `certifications_currency_anchor_lastQualifyingDive` | Last qualifying dive {date} |
| `certifications_currency_anchor_cardExpiry` | Card expiry {date} |
| `certifications_currency_anchor_cardIssue` | Issued {date} |
| `certifications_currency_anchor_ledgerEvent` | {event} logged {date} |
| `certifications_currency_alsoCovers` | Also covers {names} |
| `certifications_currency_muted` | Muted |
| `certifications_currency_action_log` | Log refresher |
| `certifications_currency_action_interval` | Edit interval |
| `certifications_currency_action_mapping` | Which dives count |
| `certifications_currency_action_mute` | Mute |
| `certifications_currency_action_unmute` | Unmute |
| `certifications_currency_history` | Currency history |
| `certifications_currency_deleteEvent_title` | Delete entry? |
| `certifications_currency_deleteEvent_content` | This removes the {event} logged {date}. |
| `certifications_currency_eventDialog_title` | Log refresher or renewal |
| `certifications_currency_eventDialog_type` | Type |
| `certifications_currency_eventDialog_date` | Date |
| `certifications_currency_eventDialog_provider` | Shop, club or instructor |
| `certifications_currency_eventDialog_notes` | Notes |
| `certifications_currency_intervalDialog_title` | Interval |
| `certifications_currency_intervalDialog_lapse` | Lapses after (days) |
| `certifications_currency_intervalDialog_lead` | Warn this many days before |
| `certifications_currency_intervalDialog_inheritHint` | Blank uses the rule's {days} |
| `certifications_currency_intervalDialog_leadTooLong` | The warning cannot start before the interval does |
| `certifications_currency_mappingDialog_title` | Which dives count |
| `certifications_currency_mappingDialog_types` | Dive types |
| `certifications_currency_mappingDialog_modes` | Dive modes |
| `certifications_currency_mappingDialog_anyHint` | Nothing selected means any dive counts |
| `certifications_currency_mappingDialog_reset` | Use the rule's default |

- [ ] **Step 1: Write the failing widget test**

Real in-memory database (`setUpTestDatabase`), a diver, a PADI OW and AOW certification, one dive from 2024 so the refresher is lapsed, `currentDiverIdProvider` mocked:

```dart
testWidgets('a lapsed refresher shows severity, anchor and advisory', ...);
testWidgets('logging a refresher flips the row to current', ...);       // dialog: pick type, date today, save
testWidgets('muting a collapsed row mutes every member', ...);          // prefs for OW and AOW both muted
testWidgets('an interval override applies to every member', ...);
testWidgets('the mapping action appears only for activity clocks', ...);
testWidgets('history lists events newest first and deletes one', ...);
testWidgets('the section is absent when nothing applies and nothing is logged', ...);
```

- [ ] **Step 2: Add the ARB keys, run `flutter gen-l10n`**

- [ ] **Step 3: Write the section**

`CertificationCurrencySection` is a `ConsumerWidget` returning `SizedBox.shrink()` when both the groups and the events are empty, otherwise a `Card` in the detail page's section style (`Padding(16)`, `titleMedium` bold title, `SizedBox(12)`). One `ListTile(contentPadding: EdgeInsets.zero)` per group:

```dart
ListTile(
  contentPadding: EdgeInsets.zero,
  leading: Icon(
    group.muted ? Icons.notifications_off_outlined : Icons.circle,
    size: group.muted ? 20 : 14,
    color: group.muted
        ? theme.colorScheme.outline
        : currencySeveritySwatch(StatusColors.of(context), group.severity)?.accent ??
            theme.colorScheme.surfaceContainerHighest,
  ),
  title: Text(currencyRuleName(l10n, s.rule)),
  subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(_dueText(l10n, units, s)),          // severity label + dueOn/lapsedSince
      Text(_anchorText(l10n, units, s), style: small),
      if (currencyRuleAdvisory(l10n, s.rule) case final advisory?)
        Text(advisory, style: small),
      if (others.isNotEmpty)
        Text(l10n.certifications_currency_alsoCovers(others), style: small),
      if (group.muted)
        TileSubtitleAction(
          label: l10n.certifications_currency_action_unmute,
          onPressed: () => _setMuted(ref, group, false),
        ),
    ],
  ),
  trailing: PopupMenuButton<_Action>(...), // log, interval, mapping (activity only), mute
)
```

Every pref write goes through one helper that writes the full value for every member, preserving that member's other fields:

```dart
Future<void> _writePrefs(
  WidgetRef ref,
  CurrencyGroup group,
  CurrencyPref Function(CurrencyPref existing) change,
) async {
  final repo = ref.read(certificationCurrencyRepositoryProvider);
  final now = DateTime.now();
  for (final m in group.members) {
    final existing = (await repo.getPrefs(m.certification.id))
            .where((p) => p.ruleId == m.rule.id)
            .firstOrNull ??
        CurrencyPref(
          id: '',
          certificationId: m.certification.id,
          ruleId: m.rule.id,
          createdAt: now,
          updatedAt: now,
        );
    await repo.upsertPref(change(existing));
  }
}
```

Mute is `_writePrefs(ref, group, (p) => p.copyWith(muted: true))`; unmute builds a new `CurrencyPref` with every field of `p` and `muted: false`. The interval dialog returns `(int? lapse, int? lead)` and the write builds a new `CurrencyPref` with those two nulls allowed (blank means inherit). The mapping dialog returns `({List<String>? types, List<DiveMode>? modes})`, with both null on "Use the rule's default".

Logging writes one event for the viewed card: `CurrencyEvent(id: '', certificationId: certification.id, ruleId: s.rule.id == kCardExpiryRuleId ? null : s.rule.id, eventType: ..., eventDate: picked, provider: ..., notes: ..., createdAt: now, updatedAt: now)`. The history list follows `_ServiceRecordTile`, with a delete `IconButton` and the error-coloured confirm dialog.

The three dialogs follow `_ScheduleOverrideDialog`: an `AlertDialog` over a `Form`, `numberValidator(context, integer: true)` on the two number fields with the inherit hint, `readNumber` on save, and a validator that rejects a lead longer than the lapse. The mapping dialog uses `DiveTypeMultiSelectField(selectedTypeIds: ..., onChanged: ..., allowEmpty: true)` and a `Wrap` of `FilterChip`s over `DiveMode.values` labelled `mode.localizedName(l10n)`.

- [ ] **Step 4: Place it**

In `certification_detail_page.dart`, after `_buildDatesSection(context, units)` and its `SizedBox(height: 16)`:

```dart
CertificationCurrencySection(certification: certification),
const SizedBox(height: 16),
```

(the section's own `SizedBox.shrink()` leaves only one 16px gap when absent; wrap the pair so the gap disappears with it).

- [ ] **Step 5: Run the section test and the existing detail page tests**

Run: `flutter test test/features/certifications`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
flutter test test/architecture
git add lib/features/certifications lib/l10n test/features/certifications
git commit -m "feat(certifications): currency section on the certification detail page"
```

---

### Task 6: Settings Manage page for the rule catalog

**Files:**
- Create: `lib/features/settings/presentation/pages/manage_currency_rules_page.dart`
- Create: `lib/features/certifications/presentation/widgets/currency_rule_edit_dialog.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (`_ManageSectionContent`, after the service types tile)
- Modify: `lib/core/router/app_router.dart` (a `/currency-rules` route beside `/dive-types`)
- Modify: ARB files
- Test: `test/features/settings/presentation/pages/manage_currency_rules_page_test.dart`
- Test: `test/features/settings/presentation/pages/settings_page_test.dart` (the Manage tile)
- Test: `test/core/router/app_router_test.dart` (builder test for `currencyRules`)

**Interfaces:**
- Consumes: `currencyRulesProvider`, `certificationCurrencyRepositoryProvider`, `currencyRuleName`, `currencyRuleAdvisory`, `CertificationAgencyDisplay`, `CertificationLevelDisplay`, `CertificationLevelCatalog.ladderFor` and `specialtiesFor`, `DiveTypeMultiSelectField`, `kFabListPadding`, `validatedCurrentDiverIdProvider`.
- Produces: `ManageCurrencyRulesPage`, route name `currencyRules` at `/currency-rules`; `showCurrencyRuleEditDialog(BuildContext context, {CurrencyRule? editing, required String? diverId}) -> Future<CurrencyRule?>`.

ARB keys (English):

| key | English |
| --- | --- |
| `settings_manage_currencyRules` | Certification currency |
| `settings_manage_currencyRules_subtitle` | Refresher and renewal rules |
| `currencyRules_title` | Certification currency |
| `currencyRules_addTooltip` | Add rule |
| `currencyRules_editTooltip` | Edit rule |
| `currencyRules_deleteTooltip` | Delete rule |
| `currencyRules_builtIn` | Built-in |
| `currencyRules_custom` | Your rules |
| `currencyRules_replaces` | Replaces {name} |
| `currencyRules_replacedBy` | Replaced by {name} |
| `currencyRules_summary_activity` | Lapses {lapse} days after the last qualifying dive |
| `currencyRules_summary_date` | Lapses {lapse} days after the card date |
| `currencyRules_deleteDialog_title` | Delete rule? |
| `currencyRules_deleteDialog_content` | {name} is removed. Logged refreshers stay in each card's history. |
| `currencyRules_dialog_addTitle` | New rule |
| `currencyRules_dialog_editTitle` | Edit rule |
| `currencyRules_dialog_copyNote` | Saving creates your own copy that replaces this built-in rule. |
| `currencyRules_dialog_name` | Name |
| `currencyRules_dialog_nameRequired` | Enter a name |
| `currencyRules_dialog_clock` | Counts from |
| `currencyRules_dialog_clock_activity` | Last qualifying dive |
| `currencyRules_dialog_clock_date` | A date on the card |
| `currencyRules_dialog_agencies` | Agencies |
| `currencyRules_dialog_levels` | Levels |
| `currencyRules_dialog_anyHint` | Nothing selected means any |
| `currencyRules_dialog_note` | Note |

- [ ] **Step 1: Write the failing page test**

Real database, a diver, `MockCurrentDiverIdNotifier`:

```dart
testWidgets('built-ins list under Built-in with no delete icon', ...);
testWidgets('the FAB adds a custom rule under Your rules', ...);
testWidgets('editing a built-in creates a custom rule that supersedes it', ...);
// tap 'Cave currency', change lapse to 200, save -> repository has a custom
// rule with supersedesRuleId 'cave_currency', diverId 'me'; the built-in row
// reads 'Replaced by <name>'; the custom row reads 'Replaces Cave currency'.
testWidgets('deleting a custom rule restores the built-in it replaced', ...);
testWidgets('the last row clears the FAB', ...);   // expectLastRowClearOfFab
testWidgets('lead longer than lapse is rejected', ...);
```

- [ ] **Step 2: Add the ARB keys, run `flutter gen-l10n`**

- [ ] **Step 3: Write the page**

Shape of `SiteTypesPage`: `Scaffold(appBar: AppBar(title: Text(l10n.currencyRules_title)), floatingActionButton: FloatingActionButton.extended(icon: const Icon(Icons.add), label: Text(l10n.currencyRules_addTooltip), tooltip: l10n.currencyRules_addTooltip, onPressed: _add), body: ListView(padding: kFabListPadding, children: [...custom section, Divider, built-in section]))`. A built-in row is tappable (opens the dialog in copy mode) and has `trailing: null`; its subtitle is a `Column` with the summary line and, when superseded, `currencyRules_replacedBy`. A custom row has `trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(edit), IconButton(delete)])` and a subtitle with the summary and, when it supersedes one, `currencyRules_replaces`.

Saving from copy mode calls `repo.createRule(edited.copyWith(id: '', isBuiltIn: false, diverId: diverId, supersedesRuleId: builtIn.id))`; saving a custom rule calls `repo.updateRule`; adding calls `repo.createRule` with `diverId`. Deleting confirms with the error-coloured `FilledButton` and calls `repo.deleteRule`; the built-in comes back by itself because nothing supersedes it any more.

- [ ] **Step 4: Write the edit dialog**

A `StatefulWidget` dialog owning its controllers: the name field (required); a `SegmentedButton<CurrencyClockKind>`; agency `FilterChip`s over `CertificationAgency.values`; level `FilterChip`s over the union of `ladderFor` and `specialtiesFor` for the selected agencies (all levels when none is selected); the lapse and lead fields with `numberValidator` and the lead-not-longer check; for activity clocks, `DiveTypeMultiSelectField(allowEmpty: true)` and the dive mode chips; the note field. In copy mode it shows `currencyRules_dialog_copyNote` above the form and prefills the name with the built-in's localized name.

- [ ] **Step 5: Route, tile and router test**

```dart
GoRoute(
  path: '/currency-rules',
  name: 'currencyRules',
  builder: (context, state) => const ManageCurrencyRulesPage(),
),
```

The Manage tile after service types: `ListTile(leading: const Icon(Icons.event_repeat_outlined), title: Text(l10n.settings_manage_currencyRules), subtitle: Text(l10n.settings_manage_currencyRules_subtitle), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/currency-rules'))`, with a `Divider(height: 1)` before it. Add the stub route and a tap test in `settings_page_test.dart`'s `buildManageWidget`, and a builder test in `app_router_test.dart`.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/settings test/core/router test/architecture`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
flutter analyze
git add lib/features/settings lib/features/certifications lib/core/router lib/l10n test/features/settings test/core/router
git commit -m "feat(settings): manage certification currency rules"
```

---

### Task 7: Whole-branch verification

- [ ] **Step 1:** `git fetch origin` and check `currentSchemaVersion` on `origin/main`; if 261 is taken, renumber (ladder, `database.dart`, the migration test file and its literals).
- [ ] **Step 2:** Merge `origin/main`, re-run codegen, `flutter analyze` before any test.
- [ ] **Step 3:** `test/l10n` (ARB parity, plural interpolation, diacritics) and `test/architecture`.
- [ ] **Step 4:** The full suite once, on its own: `flutter test`.
- [ ] **Step 5:** After screenshots of the home strip (light and dark, phone and desktop), the scoped certification list, the detail section and the Manage page.
