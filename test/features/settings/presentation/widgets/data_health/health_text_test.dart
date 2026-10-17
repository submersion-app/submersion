import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  final now = DateTime(2026, 10, 17, 12);

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  String text(
    HealthReason reason, {
    DateTime? when,
    int? count,
    String? name,
  }) => healthReasonText(
    l10n,
    FeatureHealth(
      feature: DataFeature.backup,
      level: HealthLevel.attention,
      reason: reason,
      when: when,
      count: count,
      name: name,
    ),
    now,
  );

  test('every reason shown under the strip has its own wording', () {
    const silent = {
      HealthReason.ok,
      HealthReason.notSetUp,
      HealthReason.syncCustomFolder,
    };
    final seen = <String>{};
    for (final reason in HealthReason.values) {
      final value = text(
        reason,
        when: now.subtract(const Duration(hours: 3)),
        count: 2,
        name: 'Club Sites',
      );
      if (silent.contains(reason)) {
        expect(value, isEmpty, reason: reason.name);
      } else {
        expect(value, isNotEmpty, reason: reason.name);
        expect(seen.add(value), isTrue, reason: '${reason.name} repeats');
      }
    }
  });

  test('times read as relative ages', () {
    expect(
      text(
        HealthReason.backupFailed,
        when: now.subtract(const Duration(days: 3)),
      ),
      'Last backup failed: 3d ago',
    );
    expect(
      text(
        HealthReason.syncOffline,
        when: now.subtract(const Duration(minutes: 5)),
      ),
      'Offline (last synced: 5m ago)',
    );
    expect(
      text(HealthReason.syncFailed, when: now),
      'Last sync failed: Just now',
    );
  });

  test('libraries name one failure and count several', () {
    expect(
      text(HealthReason.librariesFailed, count: 1, name: 'Club Sites'),
      'Club Sites: sync failed',
    );
    expect(
      text(HealthReason.librariesFailed, count: 3, name: 'Club Sites'),
      '3 libraries failed to sync',
    );
  });

  test('labels and routes cover every feature and level', () {
    expect(DataFeature.values.map((f) => dataFeatureLabel(l10n, f)), [
      'Backup',
      'Sync',
      'Libraries',
      'Media',
    ]);
    expect(HealthLevel.values.map((l) => healthLevelLabel(l10n, l)), [
      'Failing',
      'Needs attention',
      'Healthy',
      'Not set up',
    ]);
    expect(DataFeature.values.map(dataFeatureRoute), [
      '/settings/backup',
      '/settings/cloud-sync',
      '/settings/shared-libraries',
      '/settings/photos-media',
    ]);
  });
}
