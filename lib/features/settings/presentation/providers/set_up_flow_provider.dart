import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/accounts/account_group.dart';

/// The account chosen in step 1 of Set up this device (issue #3482), which
/// the later steps use. Lives as long as the flow is open; choosing writes
/// nothing (spec 6.4: step 1 turns no feature on).
final setUpFlowProvider =
    NotifierProvider.autoDispose<SetUpFlowNotifier, AccountGroup?>(
      SetUpFlowNotifier.new,
    );

class SetUpFlowNotifier extends Notifier<AccountGroup?> {
  @override
  AccountGroup? build() => null;

  void choose(AccountGroup account) => state = account;
}
