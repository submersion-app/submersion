// Issue #4561: the Copy row carries the backup mark for the copy's own
// problems, and a copy that needs a sign-in says so and offers it here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_copy_row.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sign_in_again_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_symbol.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _FakeSyncNotifier() : super(const SyncState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _google = AccountGroup(
  key: 'googledrive',
  kind: AccountKind.googledrive,
  label: 'Google Drive',
  address: '',
  rows: [],
  status: AccountStatus.needsSignIn,
  usages: [],
  usagesKnown: true,
  locations: {},
  roles: {},
  usageRoles: {},
  rowStatuses: {},
);

FeatureHealth _finding(HealthReason reason) => FeatureHealth(
  feature: DataFeature.backup,
  level: HealthLevel.attention,
  reason: reason,
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required BackupCopyTarget target,
    List<FeatureHealth> findings = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupCopyTargetProvider.overrideWith((ref) async => target),
          accountGroupsProvider.overrideWith((ref) async => const [_google]),
          backupHealthProvider.overrideWithValue(
            pickHealth(DataFeature.backup, findings),
          ),
          signInAgainGroupProvider(
            DataFeature.backup,
          ).overrideWith((ref) async => _google),
          syncStateProvider.overrideWith((ref) => _FakeSyncNotifier()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BackupCopyRow()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inRow(Finder f) =>
      find.descendant(of: find.byKey(const Key('backup-copy')), matching: f);

  testWidgets('no copy off this device carries the mark', (tester) async {
    await pump(
      tester,
      target: const NoCopy(),
      findings: [_finding(HealthReason.backupNoOffDeviceCopy)],
    );
    expect(inRow(find.byType(HealthSymbol)), findsOneWidget);
  });

  testWidgets('a copy needing a sign-in says so and offers it', (tester) async {
    await pump(
      tester,
      target: const CopyFollowsSync(_google),
      findings: [_finding(HealthReason.backupCloudSignIn)],
    );
    expect(inRow(find.byType(HealthSymbol)), findsOneWidget);
    expect(
      inRow(find.text('Last backup did not reach the cloud')),
      findsOneWidget,
    );
    expect(inRow(find.text('Sign in again')), findsOneWidget);
  });

  testWidgets('a copy that did not arrive says why, with no sign-in', (
    tester,
  ) async {
    await pump(
      tester,
      target: const CopyFollowsSync(_google),
      findings: [_finding(HealthReason.backupCloudCopyMissing)],
    );
    expect(inRow(find.byType(HealthSymbol)), findsOneWidget);
    expect(
      inRow(find.text('Last backup did not reach the cloud')),
      findsOneWidget,
    );
    expect(find.text('Sign in again'), findsNothing);
  });

  testWidgets('a healthy copy reads as before', (tester) async {
    await pump(tester, target: const CopyFollowsSync(_google));
    expect(find.byType(HealthSymbol), findsNothing);
    expect(find.text('Sign in again'), findsNothing);
  });
}
