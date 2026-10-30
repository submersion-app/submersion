import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/git_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_using_row.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

AccountGroup _syncGroup(AccountKind kind, String label) => groupAccounts(
  rows: [
    ConnectedAccount(
      id: 'row',
      kind: kind,
      label: label,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  ],
  statusById: const {'row': AccountStatus.signedIn},
  localLocationById: const {},
  usagesOf: (_) => const [AccountUsage(AccountUsageKind.databaseSync)],
).single;

void main() {
  Future<void> pump(
    WidgetTester tester,
    AccountGroup group,
    CloudProviderType type,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isCloudSyncDisabledByCustomFolderProvider.overrideWithValue(false),
          accountGroupsProvider.overrideWith((ref) async => [group]),
          selectedCloudProviderTypeProvider.overrideWith((ref) => type),
          gitConfigProvider.overrideWith(
            (ref) async => GitConfig(
              repoUrl: 'https://github.com/you/dive-log',
              username: 'you',
              token: 't',
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SyncUsingRow()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sync on Git shows the repository details under Using', (
    tester,
  ) async {
    await pump(
      tester,
      _syncGroup(AccountKind.git, 'you/dive-log @ github.com'),
      CloudProviderType.git,
    );
    expect(find.text('Using: you/dive-log @ github.com'), findsOneWidget);
    expect(find.byKey(const Key('git-sync-details')), findsOneWidget);
  });

  testWidgets('sync elsewhere shows no Git details', (tester) async {
    await pump(
      tester,
      _syncGroup(AccountKind.dropbox, 'Dropbox'),
      CloudProviderType.dropbox,
    );
    expect(find.byKey(const Key('git-sync-details')), findsNothing);
  });
}
