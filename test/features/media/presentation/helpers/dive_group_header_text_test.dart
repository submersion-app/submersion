import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/presentation/helpers/dive_group_header_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _units = UnitFormatter(AppSettings());

Dive _dive({
  int? number = 142,
  String? site = 'Blue Hole',
  DateTime? exit,
  Duration? runtime,
}) {
  final entry = DateTime.utc(2016, 8, 11, 9, 40);
  return Dive(
    id: 'd1',
    diveNumber: number,
    dateTime: entry,
    entryTime: entry,
    exitTime: exit,
    runtime: runtime,
    site: site == null ? null : DiveSite(id: 's1', name: site),
  );
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await initializeDateFormatting('en');
  });

  // UnitFormatter's DateFormat resolves month names against Intl.defaultLocale,
  // a process global, not the AppLocalizations loaded above. Pin it so the
  // "Aug 11, 2016" assertions state that dependency, and restore it so the
  // global stays contained when CI bundles test files in one isolate.
  setUp(() {
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
    addTearDown(() => Intl.defaultLocale = previousLocale);
  });

  ({String title, String subtitle}) header(
    Dive? dive, {
    int files = 4,
    UnitFormatter units = _units,
  }) => diveGroupHeaderText(
    dive: dive,
    fileCount: files,
    l10n: l10n,
    units: units,
  );

  test('names the dive by number and site, with its time window', () {
    final text = header(_dive(exit: DateTime.utc(2016, 8, 11, 10, 35)));

    expect(text.title, 'Dive #142 · Blue Hole');
    expect(text.subtitle, 'Aug 11, 2016 · 9:40 AM – 10:35 AM · 4 files');
  });

  test('derives the end from the runtime when no exit time is recorded', () {
    final text = header(_dive(runtime: const Duration(minutes: 52)));

    expect(text.subtitle, 'Aug 11, 2016 · 9:40 AM – 10:32 AM · 4 files');
  });

  test('shows only the start when the dive has no end to go on', () {
    // The matcher's one-hour fallback window is a guess; printing it as the
    // dive's end would tell the user something the log never recorded.
    final text = header(_dive(), files: 1);

    expect(text.subtitle, 'Aug 11, 2016 · 9:40 AM · 1 file');
  });

  test('never stands bottom time in for the dive end', () {
    // Bottom time is not runtime; start plus bottom time is not the end.
    final dive = _dive().copyWith(bottomTime: const Duration(minutes: 40));

    expect(header(dive).subtitle, 'Aug 11, 2016 · 9:40 AM · 4 files');
  });

  test('ignores an exit recorded before the entry', () {
    final text = header(_dive(exit: DateTime.utc(2016, 8, 11, 8, 55)));

    expect(text.subtitle, 'Aug 11, 2016 · 9:40 AM · 4 files');
  });

  test('dates the end too when the dive runs past midnight', () {
    // A time alone would hide the day change, so a photo from just after
    // midnight would look like it belonged to a different day.
    final entry = DateTime.utc(2016, 8, 11, 23, 30);
    final dive = Dive(
      id: 'd1',
      diveNumber: 142,
      dateTime: entry,
      entryTime: entry,
      exitTime: DateTime.utc(2016, 8, 12, 0, 20),
    );

    expect(
      header(dive).subtitle,
      'Aug 11, 2016 · 11:30 PM – Aug 12, 2016 12:20 AM · 4 files',
    );
  });

  test('drops whichever of number and site the dive lacks', () {
    expect(header(_dive(number: null)).title, 'Dive · Blue Hole');
    expect(header(_dive(site: null)).title, 'Dive #142');
    expect(header(_dive(number: null, site: null)).title, 'Dive');
  });

  test('a dive the list does not hold yet still gets a readable header', () {
    // The dive list may still be loading, or the dive was deleted mid-review:
    // never fall back to the raw id the issue complained about.
    final text = header(null, files: 2);

    expect(text.title, 'Dive');
    expect(text.subtitle, '2 files');
  });

  test("follows the diver's date and time format", () {
    const units = UnitFormatter(
      AppSettings(
        timeFormat: TimeFormat.twentyFourHour,
        dateFormat: DateFormatPreference.ddmmyyyy,
      ),
    );

    final text = header(
      _dive(exit: DateTime.utc(2016, 8, 11, 14, 5)),
      units: units,
    );

    expect(text.subtitle, startsWith('11/08/2016 · 09:40 – 14:05'));
  });

  test('every locale translates the header', () async {
    final en = header(_dive(exit: DateTime.utc(2016, 8, 11, 10, 35)));
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final local = await AppLocalizations.delegate.load(locale);
      final text = diveGroupHeaderText(
        dive: _dive(exit: DateTime.utc(2016, 8, 11, 10, 35)),
        fileCount: 4,
        l10n: local,
        units: _units,
      );
      expect(text.title, isNot(en.title), reason: locale.languageCode);
      expect(text.title, contains('142'), reason: locale.languageCode);
      expect(text.title, contains('Blue Hole'), reason: locale.languageCode);
    }
  });
}
