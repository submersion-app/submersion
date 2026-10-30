import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/sign_in_again_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Sign in again action on a sync or backup error (issue #3811). Draws
/// nothing while there is no account to offer, or while sync runs: a sign-in
/// could swap the client under it.
///
/// [onPressed] gets the account and runs `signInAgain` from a widget that
/// outlives this button, since signing in can remove it.
class SignInAgainButton extends ConsumerWidget {
  const SignInAgainButton({
    super.key,
    required this.feature,
    required this.onPressed,
    this.filled = false,
  });

  final DataFeature feature;
  final ValueChanged<AccountGroup> onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(signInAgainGroupProvider(feature)).value;
    final syncing = ref.watch(
      syncStateProvider.select((s) => s.status == SyncStatus.syncing),
    );
    if (group == null || syncing) return const SizedBox.shrink();
    final label = Text(context.l10n.settings_accounts_signInAgain);
    void press() => onPressed(group);
    return filled
        ? FilledButton(onPressed: press, child: label)
        : TextButton(onPressed: press, child: label);
  }
}
