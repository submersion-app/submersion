import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';

/// [rows] as the accounts a page lists, each signed in on this device and
/// used for nothing, for tests that stub [accountGroupsProvider] (#3482).
List<AccountGroup> signedInGroupsOf(List<ConnectedAccount> rows) =>
    groupAccounts(
      rows: rows,
      statusById: {for (final r in rows) r.id: AccountStatus.signedIn},
      localLocationById: const {},
      usagesOf: (_) => const [],
    );
