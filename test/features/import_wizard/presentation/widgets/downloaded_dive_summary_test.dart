import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/downloaded_dive_summary.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  const settings = AppSettings();

  // The spelled month and AM/PM come from intl, which resolves against
  // Intl.defaultLocale, a process global another test file in the same
  // isolate may change. Pin it, and restore it so the global stays contained.
  // Setting it explicitly makes intl demand real symbol data, so the locale
  // is initialized first.
  late String? previousLocale;

  setUpAll(() => initializeDateFormatting('en'));

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() => Intl.defaultLocale = previousLocale);

  DownloadedDive diveAt(DateTime startTime) => DownloadedDive(
    startTime: startTime,
    durationSeconds: 4680,
    maxDepth: 25.0,
    profile: const [],
  );

  // Downloaded dive times are the dive's wall clock flagged UTC, the same
  // convention every stored dive time follows. Converting one to the device's
  // zone shifts the listed time by the device's UTC offset; these fail on any
  // machine outside UTC when that conversion comes back. CI runs in UTC, where
  // they cannot tell the two apart, so
  // test/architecture/dive_time_to_local_single_source_test.dart guards the
  // conversion itself.
  test('lists the dive at its own wall-clock time', () {
    final summary = formatDownloadedDiveSummary(
      diveAt(DateTime.utc(2026, 9, 14, 9, 1, 46)),
      settings,
    );

    expect(summary.title, 'Sep 14, 2026 \u2014 9:01 AM');
  });

  test('keeps the dive on its own date just after midnight', () {
    final summary = formatDownloadedDiveSummary(
      diveAt(DateTime.utc(2026, 9, 14, 0, 30)),
      settings,
    );

    expect(summary.title, 'Sep 14, 2026 \u2014 12:30 AM');
  });
}
