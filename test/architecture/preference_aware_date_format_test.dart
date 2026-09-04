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
  final handRolled = RegExp(r'\.month\}/\$\{[A-Za-z_.!?]*\.day\}');

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

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          for (final match in namedConstructor.allMatches(line)) {
            final name = match.group(1)!;
            if (isAmbiguous(name)) {
              violations.add('$path:${i + 1}  DateFormat.$name()');
            }
          }
          if (handRolled.hasMatch(line)) {
            violations.add('$path:${i + 1}  hand-rolled M/D/Y interpolation');
          }
        }
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
}
