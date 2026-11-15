import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_using_row.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';

void main() {
  // Issue #3780: a tap that cannot open the account sheet says why.
  testWidgets('Set up says so when the accounts cannot be read', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isCloudSyncDisabledByCustomFolderProvider.overrideWithValue(false),
          accountGroupsProvider.overrideWith(
            (ref) => Future<List<AccountGroup>>.error(StateError('keychain')),
          ),
          selectedCloudProviderTypeProvider.overrideWith((ref) => null),
          // The row reads sync health for its mark (#4561).
          syncHealthProvider.overrideWithValue(
            pickHealth(DataFeature.sync, const []),
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

    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load accounts'), findsOneWidget);
  });
}
