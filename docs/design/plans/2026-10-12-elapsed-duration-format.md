# Elapsed durations in days and years Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Elapsed durations (surface intervals and a few other gaps) read as
`6d 13h` past a day and `1y 35d` past a year instead of `6379h 45m`.

**Architecture:** One shared file, `lib/core/utils/elapsed_duration_format.dart`,
splits a `Duration` into a tier and two whole numbers (`splitElapsed`), then
renders it localized (`formatElapsed`), with fixed English letters
(`formatElapsedEnglish`), or from a whole-day count (`formatElapsedDays`). Each
in-scope call site drops its hand-rolled `${h}h ${m}m` and calls one of these.

**Tech Stack:** Flutter, Dart 3 records and switch expressions, `flutter
gen-l10n` (ARB files in `lib/l10n/arb/`, 11 locales), flutter_test.

**Spec:** `docs/design/specs/2026-10-12-elapsed-duration-format-design.md`

## Global Constraints

- Tiers: under 60 min `{m} min`; under 24 h `{h}h {m}m`; under 365 d `{d}d {h}h`; 365 d and up `{y}y {d}d`.
- Both units always shown, even when the second is 0 (`2d 0h`, `2y 0d`).
- Input cut down to whole minutes with `Duration.inMinutes`; lower units cut off by integer division, never rounded up. A year is a fixed 365 days.
- Only the Time patterns card and the Focus metric round a fractional-minute average to the nearest whole minute before calling.
- Negative input renders as zero; callers that must show negatives keep their own branch.
- Day counts (dashboard chip, dive-gap observation) change only from 365 days on.
- Career and trip totals, the SI planner, no-fly and CNS countdowns, the capture-time correction slider and the other day counters are not touched.
- No em-dashes or en-dashes as punctuation anywhere (code, comments, ARB text, commits).
- Every ARB key exists in all 11 locales (`en de fr es it nl pt hu he ar zh`); `test/l10n/arb_parity_test.dart` enforces it.
- Generated `lib/l10n/arb/app_localizations*.dart` is committed with every ARB change.

## Review Focus

- A photo taken before the nearest dive has a NEGATIVE gap; the review card must format `gap.abs()`, or "before the nearest dive" would read `0 min` (Task 8 test).
- An average just under a boundary (59.6 min) must read `1h 0m`, never `60 min` or `5h 60m` (Task 3 test).
- A Chinese or German diver sees their own unit letters and number order (`6天13小时`, `6T 13h`), not English letters (Task 2 test).
- The sync-conflict dialog must still show a sub-minute value as seconds and a negative value as negative, so two versions that differ by seconds stay distinguishable (Task 6 test).
- The dive table must still show `--` for a zero or missing duration and keep bottom time `45min` exactly as today (Task 5 test).

---

### Task 1: ARB keys for the new formats

**Files:**
- Create (scratchpad, not committed): `$SCRATCH/arb_3119.py`
- Modify: `lib/l10n/arb/app_{en,de,fr,es,it,nl,pt,hu,he,ar,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces (generated `AppLocalizations` methods):
  - `String common_elapsed_minutes(int minutes)`
  - `String common_elapsed_hoursMinutes(int hours, int minutes)`
  - `String common_elapsed_daysHours(int days, int hours)`
  - `String common_elapsed_yearsDays(int years, int days)`
  - `String dashboard_gauges_lastDiveSpan(String span)`
  - `String insights_observations_diveGapSpan(String span)`
  - `String pdf_surfaceIntervalSpan(String interval)`

ARB files are feature-grouped and edited line by line (never re-dumped as JSON,
which would reformat thousands of lines). Each new key goes right after an
anchor key of the same group; in `app_en.arb` it skips past the anchor's own
`@` metadata block when that block follows it.

- [ ] **Step 1: Write the ARB edit script**

`$SCRATCH` is this session's scratchpad directory. Save as `$SCRATCH/arb_3119.py`:

```python
"""Add or remove the ARB keys for issue #3119, line by line."""
import json
import pathlib
import sys

ARB = pathlib.Path('lib/l10n/arb')
LOCALES = ['en', 'de', 'fr', 'es', 'it', 'nl', 'pt', 'hu', 'he', 'ar', 'zh']

NEW = {
    'common_elapsed_minutes': ('common_relativeTime_inDays', {
        'en': '{minutes} min', 'de': '{minutes} min', 'fr': '{minutes} min',
        'es': '{minutes} min', 'it': '{minutes} min', 'nl': '{minutes} min',
        'pt': '{minutes} min', 'hu': '{minutes} p', 'he': "{minutes} דק'",
        'ar': '{minutes} د', 'zh': '{minutes} 分钟',
    }),
    'common_elapsed_hoursMinutes': ('common_elapsed_minutes', {
        'en': '{hours}h {minutes}m', 'de': '{hours} h {minutes} min',
        'fr': '{hours} h {minutes} min', 'es': '{hours} h {minutes} min',
        'it': '{hours}h {minutes}min', 'nl': '{hours}u {minutes}m',
        'pt': '{hours}h {minutes}min', 'hu': '{hours}ó {minutes}p',
        'he': "{hours} שע' {minutes} דק'", 'ar': '{hours} س {minutes} د',
        'zh': '{hours}小时{minutes}分钟',
    }),
    'common_elapsed_daysHours': ('common_elapsed_hoursMinutes', {
        'en': '{days}d {hours}h', 'de': '{days}T {hours}h',
        'fr': '{days}j {hours}h', 'es': '{days}d {hours}h',
        'it': '{days}g {hours}h', 'nl': '{days}d {hours}u',
        'pt': '{days}d {hours}h', 'hu': '{days}n {hours}ó',
        'he': "{days} ימ' {hours} שע'", 'ar': '{days} ي {hours} س',
        'zh': '{days}天{hours}小时',
    }),
    'common_elapsed_yearsDays': ('common_elapsed_daysHours', {
        'en': '{years}y {days}d', 'de': '{years}J {days}T',
        'fr': '{years}a {days}j', 'es': '{years}a {days}d',
        'it': '{years}a {days}g', 'nl': '{years}j {days}d',
        'pt': '{years}a {days}d', 'hu': '{years}é {days}n',
        'he': "{years} שנ' {days} ימ'", 'ar': '{years} سنة {days} ي',
        'zh': '{years}年{days}天',
    }),
    'dashboard_gauges_lastDiveSpan': ('dashboard_gauges_lastDiveDays', {
        'en': 'Last dive {span} ago', 'de': 'Letzter Tauchgang vor {span}',
        'fr': 'Dernière plongée il y a {span}',
        'es': 'Última inmersión hace {span}',
        'it': 'Ultima immersione {span} fa', 'nl': 'Laatste duik {span} geleden',
        'pt': 'Último mergulho há {span}', 'hu': 'Utolsó merülés {span} ezelőtt',
        'he': 'צלילה אחרונה לפני {span}', 'ar': 'آخر غطسة منذ {span}',
        'zh': '上次潜水 {span}前',
    }),
    'insights_observations_diveGapSpan': ('insights_observations_diveGap', {
        'en': 'Your last dive was {span} ago',
        'de': 'Ihr letzter Tauchgang war vor {span}',
        'fr': 'Ta dernière plongée remonte à {span}',
        'es': 'Tu última inmersión fue hace {span}',
        'it': 'La tua ultima immersione risale a {span} fa',
        'nl': 'Uw laatste duik was {span} geleden',
        'pt': 'Seu último mergulho foi há {span}',
        'hu': 'Az utolsó merülése {span} ezelőtt volt',
        'he': 'הצלילה האחרונה שלך הייתה לפני {span}',
        'ar': 'كانت آخر غوصة لك قبل {span}',
        'zh': '您的上一次潜水是在 {span}前',
    }),
    'pdf_surfaceIntervalSpan': ('pdf_surfaceIntervalShort', {
        'en': 'SI: {interval}', 'de': 'OFP: {interval}', 'fr': 'IS : {interval}',
        'es': 'IS: {interval}', 'it': 'IS: {interval}', 'nl': 'OI: {interval}',
        'pt': 'IS: {interval}', 'hu': 'Felsz.: {interval}',
        'he': 'מרווח: {interval}', 'ar': 'فترة السطح: {interval}',
        'zh': '间隔：{interval}',
    }),
}


def _ints(*names):
    return {n: {'type': 'int'} for n in names}


def _strings(*names):
    return {n: {'type': 'String'} for n in names}


META = {
    'common_elapsed_minutes': {
        'description': 'An elapsed time under an hour, such as a short surface interval',
        'placeholders': _ints('minutes'),
    },
    'common_elapsed_hoursMinutes': {
        'description': 'An elapsed time from one hour up to a day',
        'placeholders': _ints('hours', 'minutes'),
    },
    'common_elapsed_daysHours': {
        'description': 'An elapsed time from one day up to a year, minutes left out',
        'placeholders': _ints('days', 'hours'),
    },
    'common_elapsed_yearsDays': {
        'description': 'An elapsed time of a year or more (365-day years), hours left out',
        'placeholders': _ints('years', 'days'),
    },
    'dashboard_gauges_lastDiveSpan': {
        'description': 'Dashboard chip when the last dive was a year or more ago; span is a formatted elapsed time such as 1y 35d',
        'placeholders': _strings('span'),
    },
    'insights_observations_diveGapSpan': {
        'description': 'Observation when the last dive was a year or more ago; span is a formatted elapsed time such as 1y 35d',
        'placeholders': _strings('span'),
    },
    'pdf_surfaceIntervalSpan': {
        'description': 'Short surface interval line in the NAUI logbook; interval is a formatted elapsed time',
        'placeholders': _strings('interval'),
    },
}


def key_index(lines, key):
    prefix = f'  "{key}":'
    for i, line in enumerate(lines):
        if line.startswith(prefix):
            return i
    return None


def entry_end(lines, i):
    """Last line index of the entry that starts on line i."""
    if not lines[i].rstrip().rstrip(',').endswith('{'):
        return i
    depth = 0
    for j in range(i, len(lines)):
        depth += lines[j].count('{') - lines[j].count('}')
        if depth == 0:
            return j
    raise SystemExit(f'unbalanced entry at line {i + 1}')


def add(locale, lines):
    for key, (anchor, values) in NEW.items():
        if key_index(lines, key) is not None:
            continue
        i = key_index(lines, anchor)
        if i is None:
            raise SystemExit(f'{locale}: anchor {anchor} not found')
        end = entry_end(lines, i)
        if end + 1 < len(lines) and lines[end + 1].startswith(f'  "@{anchor}":'):
            end = entry_end(lines, end + 1)
        new = [f'  "{key}": {json.dumps(values[locale], ensure_ascii=False)},\n']
        if locale == 'en':
            new.append(
                f'  "@{key}": {json.dumps(META[key], ensure_ascii=False)},\n'
            )
        lines[end + 1:end + 1] = new


def remove(locale, lines, keys):
    for key in keys:
        for name in (key, f'@{key}'):
            i = key_index(lines, name)
            if i is not None:
                del lines[i:entry_end(lines, i) + 1]


def main():
    mode, keys = sys.argv[1], sys.argv[2:]
    for locale in LOCALES:
        path = ARB / f'app_{locale}.arb'
        lines = path.read_text(encoding='utf-8').splitlines(keepends=True)
        if mode == 'add':
            add(locale, lines)
        else:
            remove(locale, lines, keys)
        text = ''.join(lines)
        json.loads(text)
        path.write_text(text, encoding='utf-8')
        print(f'OK {locale}')


main()
```

- [ ] **Step 2: Run it and regenerate**

```bash
python3.14 $SCRATCH/arb_3119.py add && flutter gen-l10n
```

Expected: `OK en` through `OK zh`, then gen-l10n exits 0 with no "untranslated" warnings for the new keys.

- [ ] **Step 3: Check the generated signatures**

```bash
grep -n "common_elapsed_\|lastDiveSpan\|diveGapSpan\|pdf_surfaceIntervalSpan" lib/l10n/arb/app_localizations.dart
```

Expected: the seven methods listed under Interfaces, with arguments in that order.

- [ ] **Step 4: Run the l10n guards**

```bash
flutter test test/l10n/
```

Expected: all pass (parity, duplicates, diacritics, Arabic plural categories).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb/ && git commit -m "feat(core): add elapsed-time strings in days and years

Refs #3119"
```

---

### Task 2: The shared elapsed-time formatter

**Files:**
- Create: `lib/core/utils/elapsed_duration_format.dart`
- Test: `test/core/utils/elapsed_duration_format_test.dart`

**Interfaces:**
- Consumes: the four `common_elapsed_*` methods from Task 1.
- Produces:
  - `enum ElapsedTier { minutes, hoursMinutes, daysHours, yearsDays }`
  - `typedef ElapsedSpan = ({ElapsedTier tier, int major, int minor});`
  - `ElapsedSpan splitElapsed(Duration elapsed)`
  - `String formatElapsed(AppLocalizations l10n, Duration elapsed)`
  - `String formatElapsedEnglish(Duration elapsed)`
  - `String? formatElapsedDays(AppLocalizations l10n, int days)`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/elapsed_duration_format.dart';
import 'package:submersion/l10n/arb/app_localizations_de.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/l10n/arb/app_localizations_zh.dart';

void main() {
  final en = AppLocalizationsEn();
  final de = AppLocalizationsDe();
  final zh = AppLocalizationsZh();

  group('splitElapsed', () {
    test('under an hour is whole minutes, seconds cut off', () {
      expect(splitElapsed(Duration.zero), (
        tier: ElapsedTier.minutes,
        major: 0,
        minor: 0,
      ));
      expect(splitElapsed(const Duration(minutes: 59, seconds: 59)), (
        tier: ElapsedTier.minutes,
        major: 59,
        minor: 0,
      ));
    });

    test('an hour up to a day is hours and minutes', () {
      expect(splitElapsed(const Duration(hours: 1)), (
        tier: ElapsedTier.hoursMinutes,
        major: 1,
        minor: 0,
      ));
      expect(splitElapsed(const Duration(hours: 23, minutes: 59)), (
        tier: ElapsedTier.hoursMinutes,
        major: 23,
        minor: 59,
      ));
    });

    test('a day up to a year is days and hours, minutes cut off', () {
      expect(splitElapsed(const Duration(days: 1)), (
        tier: ElapsedTier.daysHours,
        major: 1,
        minor: 0,
      ));
      // The two values from the issue's screenshot.
      expect(splitElapsed(const Duration(hours: 157, minutes: 42)), (
        tier: ElapsedTier.daysHours,
        major: 6,
        minor: 13,
      ));
      expect(splitElapsed(const Duration(hours: 6379, minutes: 45)), (
        tier: ElapsedTier.daysHours,
        major: 265,
        minor: 19,
      ));
      expect(splitElapsed(const Duration(days: 364, hours: 23, minutes: 59)), (
        tier: ElapsedTier.daysHours,
        major: 364,
        minor: 23,
      ));
    });

    test('a year and up is 365-day years and days, hours cut off', () {
      expect(splitElapsed(const Duration(days: 365)), (
        tier: ElapsedTier.yearsDays,
        major: 1,
        minor: 0,
      ));
      expect(splitElapsed(const Duration(days: 400, hours: 23)), (
        tier: ElapsedTier.yearsDays,
        major: 1,
        minor: 35,
      ));
      expect(splitElapsed(const Duration(days: 730)), (
        tier: ElapsedTier.yearsDays,
        major: 2,
        minor: 0,
      ));
      expect(splitElapsed(const Duration(days: 20 * 365 + 3)), (
        tier: ElapsedTier.yearsDays,
        major: 20,
        minor: 3,
      ));
    });

    test('a negative span reads as zero', () {
      expect(splitElapsed(const Duration(minutes: -90)), (
        tier: ElapsedTier.minutes,
        major: 0,
        minor: 0,
      ));
    });
  });

  group('formatElapsed', () {
    test('renders each tier in English', () {
      expect(formatElapsed(en, const Duration(minutes: 42)), '42 min');
      expect(formatElapsed(en, const Duration(hours: 5, minutes: 12)), '5h 12m');
      expect(formatElapsed(en, const Duration(hours: 157, minutes: 42)), '6d 13h');
      expect(formatElapsed(en, const Duration(days: 2)), '2d 0h');
      expect(formatElapsed(en, const Duration(days: 400)), '1y 35d');
      expect(formatElapsed(en, const Duration(days: 730)), '2y 0d');
    });

    test('uses each locale\'s own unit letters and order', () {
      expect(formatElapsed(de, const Duration(hours: 5, minutes: 12)), '5 h 12 min');
      expect(formatElapsed(de, const Duration(hours: 157, minutes: 42)), '6T 13h');
      expect(formatElapsed(de, const Duration(days: 400)), '1J 35T');
      expect(formatElapsed(zh, const Duration(hours: 157, minutes: 42)), '6天13小时');
      expect(formatElapsed(zh, const Duration(days: 400)), '1年35天');
    });
  });

  group('formatElapsedEnglish', () {
    test('renders each tier with fixed English letters', () {
      expect(formatElapsedEnglish(const Duration(minutes: 45)), '45min');
      expect(formatElapsedEnglish(const Duration(minutes: 65)), '1h 5m');
      expect(formatElapsedEnglish(const Duration(hours: 157, minutes: 42)), '6d 13h');
      expect(formatElapsedEnglish(const Duration(days: 400)), '1y 35d');
      expect(formatElapsedEnglish(const Duration(minutes: -5)), '0min');
    });
  });

  group('formatElapsedDays', () {
    test('leaves counts under a year to the caller', () {
      expect(formatElapsedDays(en, 0), isNull);
      expect(formatElapsedDays(en, 364), isNull);
    });

    test('renders a year or more as years and days', () {
      expect(formatElapsedDays(en, 365), '1y 0d');
      expect(formatElapsedDays(en, 400), '1y 35d');
      expect(formatElapsedDays(de, 400), '1J 35T');
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/core/utils/elapsed_duration_format_test.dart`
Expected: compile error, `elapsed_duration_format.dart` does not exist.

- [ ] **Step 3: Write the formatter**

```dart
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The two-unit shape an elapsed time is shown in (issue #3119).
enum ElapsedTier { minutes, hoursMinutes, daysHours, yearsDays }

/// An elapsed time reduced to its two largest units.
///
/// [major] is the larger unit of [tier] and [minor] the next one down. In the
/// [ElapsedTier.minutes] tier [minor] is always 0.
typedef ElapsedSpan = ({ElapsedTier tier, int major, int minor});

const _minutesPerHour = 60;
const _hoursPerDay = 24;
const _minutesPerDay = _hoursPerDay * _minutesPerHour;
const _daysPerYear = 365;
const _minutesPerYear = _daysPerYear * _minutesPerDay;

/// Splits [elapsed] into its two largest units.
///
/// Works in whole minutes ([Duration.inMinutes]) and cuts every lower unit
/// off rather than rounding it up, so "it has been 6d 13h" never overstates
/// the time. A year is a fixed 365 days. A negative span reads as zero; a
/// caller that must show a negative value keeps its own branch for it.
ElapsedSpan splitElapsed(Duration elapsed) {
  final total = elapsed.isNegative ? 0 : elapsed.inMinutes;
  if (total < _minutesPerHour) {
    return (tier: ElapsedTier.minutes, major: total, minor: 0);
  }
  if (total < _minutesPerDay) {
    return (
      tier: ElapsedTier.hoursMinutes,
      major: total ~/ _minutesPerHour,
      minor: total % _minutesPerHour,
    );
  }
  if (total < _minutesPerYear) {
    return (
      tier: ElapsedTier.daysHours,
      major: total ~/ _minutesPerDay,
      minor: (total % _minutesPerDay) ~/ _minutesPerHour,
    );
  }
  return (
    tier: ElapsedTier.yearsDays,
    major: total ~/ _minutesPerYear,
    minor: (total % _minutesPerYear) ~/ _minutesPerDay,
  );
}

/// [elapsed] as "42 min", "5h 12m", "6d 13h" or "1y 35d", in the diver's
/// language.
String formatElapsed(AppLocalizations l10n, Duration elapsed) {
  final span = splitElapsed(elapsed);
  return switch (span.tier) {
    ElapsedTier.minutes => l10n.common_elapsed_minutes(span.major),
    ElapsedTier.hoursMinutes => l10n.common_elapsed_hoursMinutes(
      span.major,
      span.minor,
    ),
    ElapsedTier.daysHours => l10n.common_elapsed_daysHours(
      span.major,
      span.minor,
    ),
    ElapsedTier.yearsDays => l10n.common_elapsed_yearsDays(
      span.major,
      span.minor,
    ),
  };
}

/// The same tiers as [formatElapsed] with fixed English letters ("45min",
/// "1h 5m", "6d 13h", "1y 35d").
///
/// For code paths that have no [AppLocalizations] and already print English
/// letters, such as the dive table's duration columns.
String formatElapsedEnglish(Duration elapsed) {
  final span = splitElapsed(elapsed);
  return switch (span.tier) {
    ElapsedTier.minutes => '${span.major}min',
    ElapsedTier.hoursMinutes => '${span.major}h ${span.minor}m',
    ElapsedTier.daysHours => '${span.major}d ${span.minor}h',
    ElapsedTier.yearsDays => '${span.major}y ${span.minor}d',
  };
}

/// A whole-day count of a year or more as "1y 35d", or null under a year so
/// the caller keeps its own day-count wording.
String? formatElapsedDays(AppLocalizations l10n, int days) {
  if (days < _daysPerYear) return null;
  return l10n.common_elapsed_yearsDays(days ~/ _daysPerYear, days % _daysPerYear);
}
```

- [ ] **Step 4: Run the test and watch it pass**

Run: `flutter test test/core/utils/elapsed_duration_format_test.dart`
Expected: all pass. If a de or zh string differs, the ARB value from Task 1 is the source of truth for the letters; check it was not mistyped there before changing the test.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/utils/elapsed_duration_format.dart test/core/utils/elapsed_duration_format_test.dart
git add lib/core/utils/elapsed_duration_format.dart test/core/utils/elapsed_duration_format_test.dart
git commit -m "feat(core): add a shared elapsed-time formatter with days and years

Refs #3119"
```

---

### Task 3: Insights surface-interval card and Focus metric

**Files:**
- Modify: `lib/features/insights/presentation/pages/insights_time_patterns_page.dart:288-298`
- Modify: `lib/features/insights/presentation/formatters/focus_metric_units.dart:79-100`
- Test: `test/features/insights/presentation/pages/insights_time_patterns_page_test.dart`
- Test: `test/features/insights/presentation/formatters/focus_metric_units_test.dart`

**Interfaces:**
- Consumes: `formatElapsed(AppLocalizations, Duration)` from Task 2.

- [ ] **Step 1: Write the failing tests**

In `insights_time_patterns_page_test.dart`, after the test
`'describes each chart and formats the surface intervals'`, add:

```dart
  testWidgets('long surface intervals read in days and years', (
    tester,
  ) async {
    await pumpPage(
      tester,
      days: () async => const [(dayOfWeek: 6, count: 1)],
      timesOfDay: () async => [
        DistributionSegment(label: 'Morning', count: 1, percentage: 100),
      ],
      months: () async => const [(month: 7, count: 1)],
      // 157h 42m and 400 days; the minimum sits just under an hour so the
      // rounded average must not read "60 min".
      surfaceInterval: () async =>
          (avgMinutes: 9462.0, minMinutes: 59.6, maxMinutes: 576000.0),
    );

    expect(find.text('6d 13h'), findsOneWidget);
    expect(find.text('1h 0m'), findsOneWidget);
    expect(find.text('1y 35d'), findsOneWidget);
  });
```

In `focus_metric_units_test.dart`, after `'surface interval formats as hours and minutes'`, add:

```dart
  test('surface interval past a day reads in days, past a year in years', () {
    final si = units(FocusMetric.surfaceInterval, metric);
    expect(si.format(9462, l10n), '6d 13h');
    expect(si.format(576000, l10n), '1y 35d');
    expect(si.format(59.6, l10n), '1h 0m');
  });
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/insights/presentation/pages/insights_time_patterns_page_test.dart test/features/insights/presentation/formatters/focus_metric_units_test.dart`
Expected: the two new tests fail (finds `157h 42m` style text instead).

- [ ] **Step 3: Switch both to the shared formatter**

In `insights_time_patterns_page.dart` replace `_formatMinutes` with:

```dart
  /// The stats are fractional-minute averages: round once to whole minutes,
  /// then let the shared formatter pick the tier.
  String _formatMinutes(BuildContext context, double minutes) =>
      formatElapsed(context.l10n, Duration(minutes: minutes.round()));
```

and add `import 'package:submersion/core/utils/elapsed_duration_format.dart';`
in the package-import group.

In `focus_metric_units.dart` change the surface-interval arm of `format` to

```dart
    FocusMetric.surfaceInterval => formatElapsed(
      l10n,
      Duration(minutes: storage.round()),
    ),
```

delete the `_hoursMinutes` helper and its doc comment, and add the same import.

- [ ] **Step 4: Run the tests and watch them pass**

Run the command from Step 2. Expected: all pass, including the existing
`1h 35m` / `40 min` / `3h 0m` and `45 min` expectations.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/insights test/features/insights
git add lib/features/insights/presentation/pages/insights_time_patterns_page.dart lib/features/insights/presentation/formatters/focus_metric_units.dart test/features/insights/presentation/pages/insights_time_patterns_page_test.dart test/features/insights/presentation/formatters/focus_metric_units_test.dart
git commit -m "feat(insights): show long surface intervals in days and years

Refs #3119"
```

---

### Task 4: Dive detail, dive edit and combine-dives dialog

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:3323-3357`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:2794-2806`
- Modify: `lib/features/dive_log/presentation/widgets/combine_dives_dialog.dart:776-784`
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_test.dart`
- Test: `test/features/dive_log/presentation/pages/dive_edit_page_test.dart`

**Interfaces:**
- Consumes: `formatElapsed(AppLocalizations, Duration)` from Task 2.

- [ ] **Step 1: Write the failing tests**

In `dive_detail_page_test.dart`, inside `group('DiveDetailPage bottomTime coverage', ...)`, after `'displays runtime in stat row'`, add:

```dart
    testWidgets('shows a long surface interval in days', (tester) async {
      final dive = createTestDiveWithBottomTime().copyWith(
        surfaceInterval: const Duration(hours: 157, minutes: 42),
      );
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveProvider(dive.id).overrideWith((ref) async => dive),
            diveDataSourcesProvider(
              dive.id,
            ).overrideWith((ref) async => <DiveDataSource>[]),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiveDetailPage(diveId: dive.id, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('6d 13h'), findsOneWidget);
    });
```

In `dive_edit_page_test.dart`, copy the test `'populates bottomTime field when editing existing dive'` as `'shows a long surface interval in days'`, add
`surfaceIntervalProvider(createdDive.id).overrideWith((ref) async => const Duration(days: 400))`
to the end of its overrides list (`[...buildOverrides(overrides).cast(), <that override>]`), and replace its expectations with:

```dart
      expect(find.text('1y 35d'), findsOneWidget);
```

Add the `dive_providers.dart` import if the file does not already have it.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_log/presentation/pages/dive_edit_page_test.dart`
Expected: the two new tests fail (`157h 42m` and `9600h 0m` are rendered).

- [ ] **Step 3: Switch the three sites**

In `dive_detail_page.dart`, in the `Builder` branch replace the four lines
computing `hours`, `minutes` and `intervalText` with

```dart
                  final intervalText = formatElapsed(
                    context.l10n,
                    dive.surfaceInterval!,
                  );
```

(dropping the now-unused `interval` local), and in the
`surfaceIntervalAsync.when` branch replace its three lines with

```dart
                  final intervalText = formatElapsed(context.l10n, interval);
```

In `dive_edit_page.dart` `_surfaceIntervalRow`, replace the `hours`,
`minutes` and `text` lines and the `value:` argument with

```dart
    return FormRow.display(
      label: context.l10n.diveLog_edit_row_surfaceInterval,
      value: formatElapsed(context.l10n, interval),
    );
```

In `combine_dives_dialog.dart` replace the comment and `_formatDuration` with

```dart
  // The shared elapsed-time format: a long gap between two picked dives reads
  // in days rather than hundreds of hours.
  String _formatDuration(Duration duration) =>
      formatElapsed(context.l10n, duration);
```

Add `import 'package:submersion/core/utils/elapsed_duration_format.dart';` to
all three files.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_log/presentation/pages/dive_edit_page_test.dart test/features/dive_log/presentation/widgets/`
Expected: all pass. A combine-dialog test that pinned `{n}min` now sees
`{n} min`; update only that literal. If `find.text('45 min')` in a detail test
now finds two widgets because the fixture's surface interval is also 45 min,
narrow that finder to the stat row rather than changing the fixture.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log test/features/dive_log
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/dive_log/presentation/widgets/combine_dives_dialog.dart test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_log/presentation/pages/dive_edit_page_test.dart
git commit -m "feat(dive-log): show long surface intervals in days and years

Refs #3119"
```

---

### Task 5: Dive table columns and GPS durations (English letters)

**Files:**
- Modify: `lib/core/constants/dive_field_formatter.dart:115-130`
- Modify: `lib/features/gps_log/presentation/widgets/track_row_labels.dart:22-27`
- Test: `test/core/constants/dive_field_formatter_test.dart`
- Test: `test/features/gps_log/` (new case in the file that covers `track_row_labels.dart`; create `test/features/gps_log/track_row_labels_test.dart` if none exists)

**Interfaces:**
- Consumes: `formatElapsedEnglish(Duration)` from Task 2.

- [ ] **Step 1: Write the failing tests**

In `dive_field_formatter_test.dart`, next to the existing duration cases, add:

```dart
    test('surface interval past a day reads in days, past a year in years', () {
      expect(
        DiveField.surfaceInterval.formatValue(
          const Duration(hours: 157, minutes: 42),
          units,
        ),
        '6d 13h',
      );
      expect(
        DiveField.surfaceInterval.formatValue(const Duration(days: 400), units),
        '1y 35d',
      );
    });

    test('a zero duration still reads as a dash', () {
      expect(DiveField.surfaceInterval.formatValue(Duration.zero, units), '--');
    });
```

(use the `UnitFormatter` local the file's other cases use, named `units` here.)

For `formatCompactDuration` add:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_row_labels.dart';

void main() {
  test('formatCompactDuration grows to days and years', () {
    expect(formatCompactDuration(const Duration(minutes: 47)), '47min');
    expect(formatCompactDuration(const Duration(hours: 3, minutes: 12)), '3h 12m');
    expect(formatCompactDuration(const Duration(hours: 50)), '2d 2h');
    expect(formatCompactDuration(const Duration(days: 400)), '1y 35d');
  });
}
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/core/constants/dive_field_formatter_test.dart test/features/gps_log/track_row_labels_test.dart`
Expected: the day and year cases fail (`157h 42m`, `50h 0m`).

- [ ] **Step 3: Switch both helpers**

In `dive_field_formatter.dart` replace `_formatDuration` (doc comment and body) with:

```dart
/// Format a [Duration] value as a compact elapsed time ("45min", "1h 15m",
/// "6d 13h", "1y 35d"), or "--" when missing or not positive.
String _formatDuration(dynamic value) {
  if (value is! Duration || value.inMinutes <= 0) return '--';
  return formatElapsedEnglish(value);
}
```

In `track_row_labels.dart` replace `formatCompactDuration` with:

```dart
/// Compact duration, matching the app-wide dive_field_formatter style
/// ("47min", "3h 12m", and "2d 2h" or "1y 35d" for a long recorded total).
String formatCompactDuration(Duration duration) =>
    formatElapsedEnglish(duration);
```

Add `import 'package:submersion/core/utils/elapsed_duration_format.dart';` to
both files.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `flutter test test/core/constants/ test/features/gps_log/ test/features/tracks/ test/features/dive_log/presentation/widgets/dive_table_view_test.dart test/features/dive_log/presentation/widgets/dive_table_surface_interval_test.dart test/features/dive_log/query/`
Expected: all pass, including the existing `45min`, `1h 15m`, `1h 5m` and `1h 40m` pins.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/constants lib/features/gps_log test/core/constants test/features/gps_log
git add lib/core/constants/dive_field_formatter.dart lib/features/gps_log/presentation/widgets/track_row_labels.dart test/core/constants/dive_field_formatter_test.dart test/features/gps_log/track_row_labels_test.dart
git commit -m "feat(dive-log): show long durations in the dive table and GPS log in days

Refs #3119"
```

---

### Task 6: Sync-conflict dialog durations

**Files:**
- Modify: `lib/features/settings/presentation/conflicts/conflict_field_format.dart:110-112,142-156`
- Test: `test/features/settings/presentation/conflicts/conflict_field_format_test.dart`
- Test: `test/features/settings/presentation/widgets/conflict_resolution_dialog_test.dart:336`

**Interfaces:**
- Consumes: `formatElapsed(AppLocalizations, Duration)` from Task 2.
- Produces: `String formatConflictSeconds(int seconds, AppLocalizations l10n)` (was one-argument).

- [ ] **Step 1: Write the failing test and update the old pins**

In `conflict_field_format_test.dart` change the expectation
`fmt(metric, FieldKind.durationSeconds, 2700)` from `'45min'` to `'45 min'`,
and add next to it:

```dart
      expect(fmt(metric, FieldKind.durationMinutes, 3000), '2d 2h');
      expect(fmt(metric, FieldKind.durationMinutes, 576000), '1y 35d');
      // Sub-minute and negative values keep their seconds so two versions
      // that differ only there still look different.
      expect(fmt(metric, FieldKind.durationSeconds, 42), '42s');
      expect(fmt(metric, FieldKind.durationSeconds, -30), '-30s');
```

In `conflict_resolution_dialog_test.dart:336` change `'45min'` to `'45 min'`.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/settings/presentation/conflicts/conflict_field_format_test.dart test/features/settings/presentation/widgets/conflict_resolution_dialog_test.dart`
Expected: `45 min`, `2d 2h` and `1y 35d` fail; the seconds cases pass.

- [ ] **Step 3: Thread l10n through**

Replace `formatConflictSeconds` and its doc comment with:

```dart
/// A stored count of seconds as the shared elapsed time ("45 min", "1h 5m",
/// "2d 2h").
///
/// Anything under a minute keeps its seconds instead of collapsing to
/// "0 min": two versions differing only in a sub-minute value would otherwise
/// render identically in the one dialog whose whole job is telling them
/// apart. A negative value takes the same path and shows itself rather than
/// reading as zero.
String formatConflictSeconds(int seconds, AppLocalizations l10n) {
  if (seconds < 60) return '${seconds}s';
  return formatElapsed(l10n, Duration(seconds: seconds));
}
```

and pass `l10n` at the three call sites (lines 110-112):

```dart
    FieldKind.durationSeconds => formatConflictSeconds(number.round(), l10n),
    FieldKind.durationMinutes => formatConflictSeconds(
      (number * 60).round(),
      l10n,
    ),
    FieldKind.durationHours => formatConflictSeconds(
      (number * 3600).round(),
      l10n,
    ),
```

Add the `elapsed_duration_format.dart` import. Run
`grep -rn "formatConflictSeconds(" lib test` and pass `l10n` at any other caller.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `flutter test test/features/settings/presentation/conflicts/ test/features/settings/presentation/widgets/conflict_resolution_dialog_test.dart`
Expected: all pass, including the existing `1h 15m` and `1h 30m` pins.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/settings test/features/settings
git add lib/features/settings/presentation/conflicts/conflict_field_format.dart test/features/settings/presentation/conflicts/conflict_field_format_test.dart test/features/settings/presentation/widgets/conflict_resolution_dialog_test.dart
git commit -m "feat(settings): show long durations in the sync conflict dialog in days

Refs #3119"
```

---

### Task 7: PDF logbooks

**Files:**
- Modify: `lib/core/services/pdf_templates/pdf_template_detailed.dart:362-366,909-915`
- Modify: `lib/core/services/pdf_templates/pdf_template_naui.dart:434-440`
- Test: `test/core/services/pdf_templates/pdf_surface_interval_test.dart` (new)

**Interfaces:**
- Consumes: `formatElapsed(AppLocalizations, Duration)` from Task 2; `pdf_surfaceIntervalSpan(String)` from Task 1.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_naui.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/pdf_text.dart';

/// Issue #3119: a dive after a long break has a surface interval of thousands
/// of hours, which the logbooks printed as hours or raw minutes.
void main() {
  const units = UnitFormatter(AppSettings());
  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.yyyymmdd,
    timeFormat: TimeFormat.twentyFourHour,
  );
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    runtime: const Duration(minutes: 50),
    surfaceInterval: const Duration(hours: 157, minutes: 42),
    maxDepth: 25.0,
    tanks: const [],
    profile: const [],
    gear: looseGear(const []),
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  test('detailed logbook prints a long surface interval in days', () async {
    final bytes = await PdfTemplateDetailed().buildPdf(
      dives: [dive],
      pageSize: PdfPageSize.a4,
      dates: dates,
      units: units,
    );
    expect(pdfVisibleText(bytes), contains('6d 13h'));
  });

  test('NAUI logbook prints a long surface interval in days', () async {
    final bytes = await PdfTemplateNaui().buildPdf(
      dives: [dive],
      pageSize: PdfPageSize.a4,
      dates: dates,
      units: units,
    );
    final text = pdfVisibleText(bytes);
    expect(text, contains('SI: 6d 13h'));
    expect(text, isNot(contains('9462min')));
  });
}
```

(If `Dive`'s constructor needs other required fields, copy them from the
`dives` fixture in `pdf_templates_test.dart`.)

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/core/services/pdf_templates/pdf_surface_interval_test.dart`
Expected: both fail (`157h 42m`, `SI: 9462min`).

- [ ] **Step 3: Switch both templates**

In `pdf_template_detailed.dart` change the surface-interval field to

```dart
        _Field(
          l10n.pdf_surfaceInterval,
          formatElapsed(l10n, dive.surfaceInterval!),
        ),
```

and delete `_duration` if nothing else calls it (`grep -n "_duration(" lib/core/services/pdf_templates/pdf_template_detailed.dart`).

In `pdf_template_naui.dart` change the text to

```dart
                          l10n.pdf_surfaceIntervalSpan(
                            formatElapsed(l10n, dive.surfaceInterval!),
                          ),
```

Add the `elapsed_duration_format.dart` import to both files.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `flutter test test/core/services/pdf_templates/`
Expected: all pass, including `pdf_detailed_content_test`'s 72-minute surface interval (`1h 12m`).

- [ ] **Step 5: Commit**

```bash
dart format lib/core/services/pdf_templates test/core/services/pdf_templates
git add lib/core/services/pdf_templates/pdf_template_detailed.dart lib/core/services/pdf_templates/pdf_template_naui.dart test/core/services/pdf_templates/pdf_surface_interval_test.dart
git commit -m "feat(core): print long surface intervals in days in the PDF logbooks

Refs #3119"
```

---

### Task 8: Photo review gap to the nearest dive

**Files:**
- Modify: `lib/features/media/presentation/widgets/file_review_card.dart:166`
- Test: `test/features/media/presentation/widgets/file_review_card_test.dart`

**Interfaces:**
- Consumes: `formatElapsed(AppLocalizations, Duration)` from Task 2.

- [ ] **Step 1: Write the failing tests**

After `'reports how far a late file missed the nearest dive'`, add:

```dart
    testWidgets('a file weeks away from any dive reads in days', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        file: _ef('/tmp/photo.jpg'),
        diagnostic: const UnmatchedDiagnostic(
          reason: UnmatchedReason.outsideAllWindows,
          nearestDiveId: 'dive-1',
          gapToNearest: Duration(days: 20, hours: 5, minutes: 9),
        ),
      );

      expect(find.text('20d 5h after the nearest dive'), findsOneWidget);
    });

    testWidgets('an early file far from any dive reads in days too', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        file: _ef('/tmp/photo.jpg'),
        diagnostic: const UnmatchedDiagnostic(
          reason: UnmatchedReason.outsideAllWindows,
          nearestDiveId: 'dive-1',
          gapToNearest: Duration(days: -400),
        ),
      );

      expect(find.text('1y 35d before the nearest dive'), findsOneWidget);
    });
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/media/presentation/widgets/file_review_card_test.dart`
Expected: the two new tests fail (`485h 09m`, `9600h 00m`).

- [ ] **Step 3: Switch the reason line**

Replace `final magnitude = formatOffsetMagnitude(gap);` with

```dart
        // The sentence carries the direction, so format the size only.
        final magnitude = formatElapsed(l10n, gap.abs());
```

Add the `elapsed_duration_format.dart` import, and drop the
`capture_time_offset_format.dart` import if the file no longer uses it.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `flutter test test/features/media/`
Expected: all pass, including `3h 38m after the nearest dive` and the early-file case, and the untouched `capture_time_offset_format_test.dart`.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media test/features/media
git add lib/features/media/presentation/widgets/file_review_card.dart test/features/media/presentation/widgets/file_review_card_test.dart
git commit -m "feat(media): show a photo's long gap to the nearest dive in days

Refs #3119"
```

---

### Task 9: Day counts past a year

**Files:**
- Modify: `lib/features/dashboard/presentation/widgets/gauge_strip.dart:283-285`
- Modify: `lib/features/insights/presentation/formatters/observation_sentence.dart:134-135`
- Test: `test/features/dashboard/presentation/widgets/gauge_strip_test.dart`
- Test: `test/features/insights/presentation/formatters/observation_sentence_test.dart`

**Interfaces:**
- Consumes: `formatElapsedDays(AppLocalizations, int)` from Task 2; `dashboard_gauges_lastDiveSpan(String)` and `insights_observations_diveGapSpan(String)` from Task 1.

- [ ] **Step 1: Write the failing tests**

In `gauge_strip_test.dart`, `group('dive currency chip')`, change
`'past the alert threshold'` to expect `'Last dive 1y 1d ago'` (366 days), and add:

```dart
    testWidgets('just under a year still counts days', (tester) async {
      await pumpDays(tester, 364);
      expect(find.text('Last dive 364d ago'), findsOneWidget);
    });

    testWidgets('a long break reads in years and days', (tester) async {
      await pumpDays(tester, 800);
      expect(find.text('Last dive 2y 70d ago'), findsOneWidget);
    });
```

In `observation_sentence_test.dart`, in `'dive gap and busiest month'`, after
the 120-day expectation add:

```dart
    expect(
      observationSentence(
        _o(
          ObservationRuleId.diveGap,
          DiveGapFacts(
            days: 400,
            lastDiveId: 'd',
            lastDiveDate: DateTime.utc(2025),
          ),
        ),
        en,
        metric,
      ),
      'Your last dive was 1y 35d ago',
    );
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/dashboard/presentation/widgets/gauge_strip_test.dart test/features/insights/presentation/formatters/observation_sentence_test.dart`
Expected: the 366, 800 and 400-day cases fail.

- [ ] **Step 3: Switch both sites**

In `gauge_strip.dart`, above `chips.add(` in the last-dive block, add

```dart
      // From a year on the bare day count stops being readable.
      final longGap = days == null ? null : formatElapsedDays(l10n, days);
```

and change the last arm of the label to

```dart
              : longGap != null
              ? l10n.dashboard_gauges_lastDiveSpan(longGap)
              : l10n.dashboard_gauges_lastDiveDays(days),
```

In `observation_sentence.dart` change the dive-gap arm to

```dart
    (ObservationRuleId.diveGap, final DiveGapFacts g) =>
      switch (formatElapsedDays(l10n, g.days)) {
        final span? => l10n.insights_observations_diveGapSpan(span),
        null => l10n.insights_observations_diveGap(g.days),
      },
```

Add the `elapsed_duration_format.dart` import to both files.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `flutter test test/features/dashboard/ test/features/insights/`
Expected: all pass; the per-rule placeholder table in `observation_sentence_test.dart` (`'123'`) is unchanged.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dashboard lib/features/insights test/features/dashboard test/features/insights
git add lib/features/dashboard/presentation/widgets/gauge_strip.dart lib/features/insights/presentation/formatters/observation_sentence.dart test/features/dashboard/presentation/widgets/gauge_strip_test.dart test/features/insights/presentation/formatters/observation_sentence_test.dart
git commit -m "feat(insights): show a last dive over a year ago in years and days

Refs #3119"
```

---

### Task 10: Remove orphaned keys and run the full checks

**Files:**
- Modify: `lib/l10n/arb/app_*.arb`, regenerate `lib/l10n/arb/app_localizations*.dart`

- [ ] **Step 1: Confirm which old keys have no caller**

```bash
for k in insights_timePatterns_surfaceInterval_formatHoursMinutes insights_timePatterns_surfaceInterval_formatMinutes pdf_surfaceIntervalShort pdf_hoursMinutes pdf_minutesShort; do printf '%s ' "$k"; grep -rn "\.$k(" lib test | grep -v "lib/l10n/arb/" | wc -l; done
```

Expected: 0 for the first three. Remove only keys that print 0
(`pdf_hoursMinutes` is still used by `pdf_shared_components.dart`).

- [ ] **Step 2: Remove them and regenerate**

```bash
python3.14 $SCRATCH/arb_3119.py remove insights_timePatterns_surfaceInterval_formatHoursMinutes insights_timePatterns_surfaceInterval_formatMinutes pdf_surfaceIntervalShort && flutter gen-l10n
```

(append `pdf_minutesShort` if Step 1 printed 0 for it.) Expected: `OK` for
all 11 locales; gen-l10n exits 0.

- [ ] **Step 3: Full checks**

```bash
dart format . && flutter analyze && flutter test test/l10n/ test/architecture/ test/shared/ test/core/ test/features/insights/ test/features/dive_log/ test/features/dashboard/ test/features/media/ test/features/settings/ test/features/gps_log/ test/features/tracks/
```

Expected: no format changes left, no analyzer issues, all tests pass.

- [ ] **Step 4: Dash scan**

```bash
git diff origin/main --unified=0 | grep "^+" | python3.14 -c "import sys; t=sys.stdin.read(); print('em', t.count(chr(0x2014)), 'en', t.count(chr(0x2013)))"
```

Expected: `em 0 en 0`.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb/ && git commit -m "refactor(core): drop duration strings replaced by the elapsed format

Refs #3119"
```
