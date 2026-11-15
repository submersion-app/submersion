import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_status_line.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
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

class _FakeSettings extends StateNotifier<BackupSettings>
    implements BackupSettingsNotifier {
  _FakeSettings() : super(const BackupSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const group = AccountGroup(
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

  Future<void> pump(
    WidgetTester tester,
    HealthReason reason, {
    HealthLevel level = HealthLevel.attention,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupSettingsProvider.overrideWith((ref) => _FakeSettings()),
          backupHealthProvider.overrideWithValue(
            pickHealth(DataFeature.backup, [
              FeatureHealth(
                feature: DataFeature.backup,
                level: level,
                reason: reason,
              ),
            ]),
          ),
          signInAgainGroupProvider(
            DataFeature.backup,
          ).overrideWith((ref) async => group),
          syncStateProvider.overrideWith((ref) => _FakeSyncNotifier()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BackupStatusLine()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Issue #4561: the sign-in belongs to the copy, so the Copy row carries
  // it; the status line keeps to what is true of the last backup.
  testWidgets('a copy needing a sign-in leaves the line plain', (tester) async {
    await pump(tester, HealthReason.backupCloudSignIn);

    expect(find.text('Last backup did not reach the cloud'), findsNothing);
    expect(find.text('Sign in again'), findsNothing);
    expect(find.byType(HealthSymbol), findsNothing);
  });

  testWidgets('a failed backup is marked, its icon left uncoloured', (
    tester,
  ) async {
    await pump(tester, HealthReason.backupFailed, level: HealthLevel.failing);

    expect(
      tester.widget<HealthSymbol>(find.byType(HealthSymbol)).level,
      HealthLevel.failing,
    );
    expect(tester.widget<Icon>(find.byIcon(Icons.error_outline)).color, isNull);
  });

  testWidgets('an overdue backup is marked', (tester) async {
    await pump(tester, HealthReason.backupOverdue);

    expect(find.byType(HealthSymbol), findsOneWidget);
  });

  testWidgets('a reason about another row leaves the line unmarked', (
    tester,
  ) async {
    await pump(tester, HealthReason.backupAutoOff);

    expect(find.byType(HealthSymbol), findsNothing);
  });
}
