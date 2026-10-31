import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sign_in.dart';

/// The account Sign in again would run for [DataFeature], or null when there
/// is none to offer (issue #3811): nothing uses an account for it, the system
/// manages the account (iCloud), or this build has no sign-in for it. The
/// error then reads as it did, and tapping it opens its page.
///
/// Not retried: a failed read of the roster just offers nothing until the
/// next visit, and the error underneath still shows.
final signInAgainGroupProvider = FutureProvider.autoDispose
    .family<AccountGroup?, DataFeature>((ref, feature) async {
      final group = switch (feature) {
        DataFeature.sync => (await ref.watch(
          accountGroupsProvider.future,
        )).syncing,
        DataFeature.backup => backupCopyGroupOf(
          await ref.watch(backupCopyTargetProvider.future),
        ),
        DataFeature.sharedLibraries || DataFeature.media => null,
      };
      if (group == null) return null;
      final canSignIn =
          group.kind != AccountKind.icloud &&
          group.kind != AccountKind.adobeLightroom &&
          await canSignInOnThisBuild(ref.read, group.kind);
      return canSignIn ? group : null;
    }, retry: (_, _) => null);
