import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/presentation/widgets/dive_identity_label.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_message.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations l10n;

  // Formatters tag their output so assertions can prove the summary's raw
  // values were routed through the diver's unit and date preferences rather
  // than formatted inline.
  final fmt = QualityUnitFormatters(
    depth: (m) => 'D${m.toStringAsFixed(1)}',
    pressure: (bar) => 'P${bar.toStringAsFixed(1)}',
    temperature: (c) => 'T${c.toStringAsFixed(1)}',
    sac: (lpm) => 'S${lpm.toStringAsFixed(1)}',
    date: (d) => 'DATE(${d.year}-${d.month}-${d.day})',
    dateTime: (d) =>
        'WHEN(${d.year}-${d.month}-${d.day} ${d.hour}:${d.minute})',
  );

  setUp(() {
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  DiveSummary summary({
    int? diveNumber,
    String? name,
    String? siteName,
    DateTime? entryTime,
    DateTime? dateTime,
    double? maxDepth,
    Duration? runtime,
    Duration? bottomTime,
  }) {
    final stamp = dateTime ?? DateTime.utc(2026, 6, 14, 9, 12);
    return DiveSummary(
      id: 'd1',
      diveNumber: diveNumber,
      name: name,
      dateTime: stamp,
      entryTime: entryTime,
      maxDepth: maxDepth,
      runtime: runtime,
      bottomTime: bottomTime,
      siteName: siteName,
      sortTimestamp: (entryTime ?? stamp).millisecondsSinceEpoch,
    );
  }

  DiveIdentityLabel label(DiveSummary? s) =>
      buildDiveIdentityLabel(summary: s, l10n: l10n, formatters: fmt);

  group('headline', () {
    test('joins dive number, site, and entry time', () {
      final result = label(
        summary(
          diveNumber: 42,
          siteName: 'Blue Hole',
          entryTime: DateTime.utc(2026, 6, 14, 9, 12),
        ),
      );
      expect(result.headline, '#42 · Blue Hole · WHEN(2026-6-14 9:12)');
    });

    test("a dive's own name wins over the site name", () {
      final result = label(
        summary(diveNumber: 42, name: 'Shark alley', siteName: 'Blue Hole'),
      );
      expect(result.headline, startsWith('#42 · Shark alley · '));
      expect(result.headline, isNot(contains('Blue Hole')));
    });

    test('a whitespace-only name is treated as unset', () {
      final result = label(summary(name: '   ', siteName: 'Blue Hole'));
      expect(result.headline, startsWith('Blue Hole · '));
    });

    test('drops the number segment when the dive is unnumbered', () {
      final result = label(summary(siteName: 'Blue Hole'));
      expect(result.headline, 'Blue Hole · WHEN(2026-6-14 9:12)');
      expect(result.headline, isNot(contains('#')));
    });

    // The reported bug: an unnamed, siteless dive rendered its raw UUID, so
    // the inbox named no dive the diver could recognize. Date and time are
    // always available, so the headline is never an id.
    test('falls back to date and time, never an id, with no name or site', () {
      final result = label(summary());
      expect(result.headline, 'WHEN(2026-6-14 9:12)');
      expect(result.headline, isNot(contains('d1')));
    });

    test('prefers the entry time over the stored dive date', () {
      final result = label(
        summary(
          dateTime: DateTime.utc(2026, 6, 14),
          entryTime: DateTime.utc(2026, 6, 14, 9, 12),
        ),
      );
      expect(result.headline, 'WHEN(2026-6-14 9:12)');
    });

    test('says so plainly when the dive is gone', () {
      final result = label(null);
      expect(result.headline, l10n.dataQuality_dive_unknown);
      expect(result.stats, isNull);
    });
  });

  group('stats', () {
    test('renders depth through the diver unit formatter and duration', () {
      final result = label(
        summary(maxDepth: 28.4, runtime: const Duration(minutes: 47)),
      );
      expect(result.stats, 'D28.4 · 47 min');
    });

    test('falls back to bottom time when there is no runtime', () {
      final result = label(summary(bottomTime: const Duration(minutes: 31)));
      expect(result.stats, '31 min');
    });

    test('is null when neither depth nor duration is known', () {
      expect(label(summary(diveNumber: 7)).stats, isNull);
    });
  });
}
