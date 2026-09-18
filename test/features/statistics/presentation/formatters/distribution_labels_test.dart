import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/formatters/distribution_labels.dart';
import 'package:submersion/l10n/arb/app_localizations_de.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final en = AppLocalizationsEn();
  final de = AppLocalizationsDe();

  group('not recorded share (issue #1998)', () {
    test('water type names the dives with no water type', () {
      expect(
        waterTypeDistributionLabel(DistributionSegment.notRecordedKey, en),
        'Not recorded',
      );
      expect(
        waterTypeDistributionLabel(DistributionSegment.notRecordedKey, de),
        de.statistics_chart_notRecorded,
      );
    });

    test('entry method names the dives with no entry method', () {
      expect(
        entryMethodDistributionLabel(DistributionSegment.notRecordedKey, en),
        'Not recorded',
      );
    });

    test('recorded values are still translated from their enum name', () {
      expect(waterTypeDistributionLabel('salt', en), isNot('salt'));
      expect(entryMethodDistributionLabel('shore', en), isNot('shore'));
    });
  });
}
