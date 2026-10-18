// Issue #3482: each row status kind renders as one plain sentence.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/domain/data_health/data_row_status.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_row_status_text.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final now = DateTime(2026, 10, 18, 12);
  final when = DateTime(2026, 10, 18, 11, 48);

  Future<AppLocalizations> l10n(WidgetTester tester) async {
    late AppLocalizations l;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return l;
  }

  testWidgets('renders each kind in English', (tester) async {
    final l = await l10n(tester);
    String text(DataRowStatus s) => dataRowStatusText(l, s, now);

    expect(
      text(const DataRowStatus(DataRowStatusKind.backupsNever)),
      'Not backed up yet',
    );
    expect(
      text(DataRowStatus(DataRowStatusKind.backupsLocal, when: when)),
      'Backed up 12m ago, on this device only',
    );
    expect(
      text(
        DataRowStatus(
          DataRowStatusKind.backupsCloud,
          when: when,
          name: 'Google Drive',
        ),
      ),
      'Backed up 12m ago, copy in Google Drive',
    );
    expect(
      text(DataRowStatus(DataRowStatusKind.backupsFolder, when: when)),
      'Backed up 12m ago, copy in your backup folder',
    );
    expect(
      text(DataRowStatus(DataRowStatusKind.backupsFailed, when: when)),
      'Last backup failed: 12m ago',
    );
    expect(
      text(const DataRowStatus(DataRowStatusKind.syncOff)),
      'Only on this device',
    );
    expect(
      text(const DataRowStatus(DataRowStatusKind.syncNever)),
      'Not synced yet',
    );
    expect(
      text(DataRowStatus(DataRowStatusKind.syncAlone, when: when)),
      'Synced 12m ago, only this device so far',
    );
    expect(
      text(
        DataRowStatus(
          DataRowStatusKind.syncWithOne,
          when: when,
          name: "Eric's iPhone",
        ),
      ),
      "In step with Eric's iPhone, 12m ago",
    );
    expect(
      text(DataRowStatus(DataRowStatusKind.syncWithMany, when: when, count: 3)),
      'In step with 3 devices, 12m ago',
    );
    expect(
      text(const DataRowStatus(DataRowStatusKind.photosOff)),
      'Copies are not kept in the cloud',
    );
    expect(
      text(const DataRowStatus(DataRowStatusKind.photosOn, name: 'b @ host')),
      'Copies kept in b @ host',
    );
    expect(
      text(const DataRowStatus(DataRowStatusKind.photosOn, name: '')),
      'Copies kept in the cloud',
    );
    expect(
      text(const DataRowStatus(DataRowStatusKind.photosOn)),
      'Copies kept in the cloud',
    );
    expect(
      text(const DataRowStatus(DataRowStatusKind.librariesNone)),
      'None joined',
    );
    expect(
      text(
        DataRowStatus(DataRowStatusKind.librariesSome, count: 1, when: when),
      ),
      '1 library, last sync 12m ago',
    );
    expect(
      text(const DataRowStatus(DataRowStatusKind.librariesSomeNever, count: 2)),
      '2 libraries, not synced yet',
    );
    expect(
      text(const DataRowStatus(DataRowStatusKind.accountsNone)),
      'None yet',
    );
    expect(
      text(const DataRowStatus(DataRowStatusKind.checking)),
      'Checking\u2026',
    );
    expect(
      text(
        const DataRowStatus(
          DataRowStatusKind.accountsListed,
          name: 'Google Drive, nas.home',
        ),
      ),
      'Google Drive, nas.home',
    );
    // No account label (still loading, or no roster row for sync) never
    // leaves a dangling "copy in ".
    expect(
      text(DataRowStatus(DataRowStatusKind.backupsCloud, when: when)),
      'Backed up 12m ago, copy in the cloud',
    );
    expect(
      text(
        DataRowStatus(DataRowStatusKind.backupsCloud, when: when, name: ' '),
      ),
      'Backed up 12m ago, copy in the cloud',
    );
    // Mid-sentence times are lowercase, unlike the standalone label.
    expect(
      text(DataRowStatus(DataRowStatusKind.backupsLocal, when: now)),
      'Backed up just now, on this device only',
    );
    expect(
      text(
        DataRowStatus(
          DataRowStatusKind.syncWithOne,
          when: now,
          name: "Eric's iPhone",
        ),
      ),
      "In step with Eric's iPhone, just now",
    );
    expect(
      text(const DataRowStatus(DataRowStatusKind.accountsNeedSignIn, count: 2)),
      '2 accounts need sign-in',
    );
  });

  testWidgets('health-backed kinds reuse the attention line text', (
    tester,
  ) async {
    final l = await l10n(tester);
    const paused = FeatureHealth(
      feature: DataFeature.sync,
      level: HealthLevel.failing,
      reason: HealthReason.syncNeedsPassphrase,
    );
    const photos = FeatureHealth(
      feature: DataFeature.media,
      level: HealthLevel.attention,
      reason: HealthReason.mediaTransfersPaused,
    );
    const library = FeatureHealth(
      feature: DataFeature.sharedLibraries,
      level: HealthLevel.attention,
      reason: HealthReason.librariesEditsHeld,
      name: 'Club Sites',
    );
    expect(
      dataRowStatusText(
        l,
        const DataRowStatus(DataRowStatusKind.syncAttention, health: paused),
        now,
      ),
      healthReasonText(l, paused, now),
    );
    expect(
      dataRowStatusText(
        l,
        const DataRowStatus(DataRowStatusKind.photosAttention, health: photos),
        now,
      ),
      healthReasonText(l, photos, now),
    );
    expect(
      dataRowStatusText(
        l,
        const DataRowStatus(
          DataRowStatusKind.librariesAttention,
          health: library,
          count: 1,
        ),
        now,
      ),
      healthReasonText(l, library, now),
    );
  });
}
