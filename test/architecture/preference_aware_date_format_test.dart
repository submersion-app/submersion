import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Presentation code must render dates through `UnitFormatter`, which reads the
/// diver's `DateFormatPreference` from Manage - Units, and never through a
/// locale-derived `DateFormat` named constructor.
///
/// `DateFormat.yMMMd()` resolves against `Intl.defaultLocale`, so on an English
/// UI it always renders "Jan 6, 1983". A diver who picked D MMM YYYY sees the
/// wrong order and there is nothing in the widget to hint at it, which is how
/// #1512 reached a release across Trips, Certifications, the update check and
/// the equipment editor at once. This scan is the ratchet: every offender was
/// converted, so any new one is a regression.
///
/// The `UnitFormatter` replacements are `formatDate`, `formatDateTime`,
/// `formatDateTimeBullet`, `formatMonthDay`, `formatWeekdayMonthDay`,
/// `formatMonthDayWithYear` and `formatMonthYear`.
void main() {
  /// Directories whose whole job is drawing the UI.
  const scannedRoots = ['lib/core/presentation', 'lib/shared', 'lib/features'];

  /// Only presentation code is scanned inside `lib/features`; parsers,
  /// serialisers and repositories legitimately pin a machine format.
  bool isScanned(String path) {
    if (!path.startsWith('lib/features/')) return true;
    return path.contains('/presentation/');
  }

  /// Files that keep a fixed format on purpose, each with the reason.
  const allowed = <String, String>{
    // Timestamps that end up in a filename, which must sort and must not
    // contain a slash.
    'lib/features/settings/presentation/pages/storage_settings_page.dart':
        'export filename stamp',
    // The Material date picker's own manual-entry hint, already derived from
    // the preference by showAppDatePicker.
    'lib/shared/widgets/app_date_picker.dart':
        'picker hint, preference-derived',
    // Fixed two-character month/year printed inside the CR80 card art, where
    // the width budget is the constraint rather than the reading order.
    'lib/features/certifications/presentation/services/certification_card_renderer.dart':
        'CR80 card art, fixed width budget',
    // The terminal startup-failure screen renders when the database could not
    // be opened, so the diver's saved preferences are not readable at all and
    // the resolved system locale is the only source of formatting there.
    'lib/core/presentation/widgets/startup_failure_view.dart':
        'renders before settings are readable',
    // The printed card face imitates a physical certification card, so it
    // keeps that card's compact month/year whatever the diver picked. There is
    // no day to reorder; the spoken Semantics label carries the full date in
    // the diver's own order instead. Pinned by
    // certification_ecard_test.dart, "keeps the card face month/year under a
    // day-first preference".
    'lib/features/certifications/presentation/widgets/certification_ecard_front.dart':
        'card face imitates the physical card',
  };

  /// A named constructor is ambiguous when it carries a day, or a month
  /// alongside a year: "10/8" and "Jun 2024" both read differently to a diver
  /// on a day-first or ISO preference. A bare weekday (`E`), a bare month name
  /// (`MMMM`), a bare year (`y`) and the time constructors have no order to
  /// get wrong.
  bool isAmbiguous(String constructorName) =>
      constructorName.contains('d') ||
      (constructorName.contains('y') && constructorName.contains('M'));

  final namedConstructor = RegExp(r'\bDateFormat\.([A-Za-z]+)\s*\(');

  // '${date.month}/${date.day}/${date.year}': a hand-rolled M/D/YYYY cannot
  // honour any preference at all. Slash-separated only, so a dash-joined map
  // key such as '$y-$m-$d' stays out of it: that is a machine string, and an
  // ISO ordering is unambiguous anyway.
  final handRolled = RegExp(
    r'\.month\}/[^A-Za-z]{0,6}\$\{[A-Za-z_.!?]*\.day\}',
  );

  // MaterialLocalizations formats from the resolved UI locale, which is the
  // same defect as DateFormat.yMMMd() wearing different clothes: it was how
  // the pre-dive, planner and equipment surfaces still ignored the preference
  // after the first sweep, because no search for "DateFormat" reaches them.
  //
  // Only the four `format*Date` names are matched unconditionally: they exist
  // nowhere else. `formatMonthYear` is also a UnitFormatter method, and the
  // correct one, so it counts only alongside the MaterialLocalizations
  // receiver on the same line.
  final materialDate = RegExp(r'\.format(Medium|Full|Compact|Short)Date\b');
  final materialMonthYear = RegExp(
    r'MaterialLocalizations[^;]{0,200}formatMonthYear\b',
  );

  // TimeOfDay.format reads MediaQuery's alwaysUse24HourFormat, the platform
  // setting, rather than the diver's TimeFormat.
  final timeOfDay = RegExp(
    r'\bTimeOfDay[^;\n]*\.format\(context\)|\.formatTimeOfDay\b',
  );

  /// Joins [lines] into one string, trimmed and space-separated, appending
  /// each line's start offset to [lineStarts] so a match can be mapped back to
  /// the line its call began on.
  String flatten(List<String> lines, [List<int>? lineStarts]) {
    final flat = StringBuffer();
    for (final line in lines) {
      lineStarts?.add(flat.length);
      flat.write(line.trim());
      flat.write(' ');
    }
    return flat.toString();
  }

  test('presentation code formats dates from the diver preference', () {
    final violations = <String>[];

    for (final root in scannedRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // Normalise separators: Directory.listSync yields platform paths, so
        // on Windows every 'lib/features/' prefix and allowlist key below
        // would miss and the scan would report phantom violations.
        final path = entity.path.replaceAll('\\', '/');
        if (!isScanned(path) || allowed.containsKey(path)) continue;

        // Scan the file as one flattened string, not line by line. dart
        // format splits a chain the moment it runs long, and
        // `MaterialLocalizations.of(\n  context,\n).formatShortDate(x)` is the
        // shape it produces for exactly the calls this scan hunts. A per-line
        // test sees three fragments and matches none of them.
        //
        // Each line is trimmed and joined with a single space, so the patterns
        // below tolerate the whitespace the join introduces. `lineStarts`
        // maps a match offset back to the line the call began on.
        final lines = entity.readAsLinesSync();
        final lineStarts = <int>[];
        final text = flatten(lines, lineStarts);

        int lineOf(int offset) {
          var low = 0;
          var high = lineStarts.length - 1;
          while (low < high) {
            final mid = (low + high + 1) ~/ 2;
            if (lineStarts[mid] <= offset) {
              low = mid;
            } else {
              high = mid - 1;
            }
          }
          return low + 1;
        }

        void report(
          RegExp pattern,
          String what, {
          bool Function(RegExpMatch)? when,
        }) {
          for (final match in pattern.allMatches(text)) {
            if (when != null && !when(match)) continue;
            violations.add('$path:${lineOf(match.start)}  $what');
          }
        }

        for (final match in namedConstructor.allMatches(text)) {
          final name = match.group(1)!;
          if (isAmbiguous(name)) {
            violations.add('$path:${lineOf(match.start)}  DateFormat.$name()');
          }
        }
        report(handRolled, 'hand-rolled M/D/Y interpolation');
        report(materialDate, 'MaterialLocalizations date');
        report(materialMonthYear, 'MaterialLocalizations date');
        report(timeOfDay, 'TimeOfDay.format(context)');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'These render a date from the ambient locale instead of the diver\'s '
          'DateFormatPreference (#1512). Use UnitFormatter, reached with '
          'UnitFormatter(ref.watch(settingsProvider)). If a fixed format is '
          'genuinely required, add the file to the allowlist above with its '
          'reason.\n${violations.join('\n')}',
    );
  });

  // The scan is only worth trusting if it survives dart format. Each sample
  // below is the shape the formatter produces once the call runs long, which
  // is precisely when a line-by-line scan stops seeing it.
  test('the patterns survive a call split across lines', () {
    expect(
      materialDate.hasMatch(
        flatten([
          'final formatted = MaterialLocalizations.of(',
          '  context,',
          ').formatShortDate(dueDate);',
        ]),
      ),
      isTrue,
    );

    expect(
      materialMonthYear.hasMatch(
        flatten([
          'final label = MaterialLocalizations.of(',
          '  context,',
          ').formatMonthYear(when);',
        ]),
      ),
      isTrue,
    );

    expect(
      timeOfDay.hasMatch(
        flatten([
          'final t = TimeOfDay.fromDateTime(',
          '  value,',
          ').format(context);',
        ]),
      ),
      isTrue,
    );

    expect(
      handRolled.hasMatch(
        flatten(["final s = '\${d.month}/'", "    '\${d.day}/\${d.year}';"]),
      ),
      isTrue,
    );

    expect(
      namedConstructor
          .allMatches(flatten(['DateFormat', '  .yMMMd()', '  .format(x);']))
          .isEmpty,
      isTrue,
      reason:
          'a receiver split before the dot is not a shape dart format emits, '
          'and matching it would need a parser rather than a regex',
    );

    // The two shapes that must stay quiet: an ISO map key, and
    // UnitFormatter's own formatMonthYear.
    expect(
      handRolled.hasMatch(
        flatten(["return '\${d.year}-\${d.month}-\${d.day}';"]),
      ),
      isFalse,
    );
    expect(
      materialMonthYear.hasMatch(
        flatten(['units.formatMonthYear(header.monthStart),']),
      ),
      isFalse,
    );
  });
}
