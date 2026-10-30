import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized text for a Git failure on the settings screens, each saying
/// what to do next, followed by the host's own words when it gave any.
/// [branch] fills the messages that name the branch.
String gitErrorText(
  AppLocalizations l10n,
  GitException e, {
  required String branch,
}) {
  final size = e.sizeBytes;
  final text = switch (e.code) {
    GitErrorCode.invalidConfig => l10n.settings_gitConfig_error_invalidConfig,
    GitErrorCode.unauthorized => l10n.settings_gitConfig_error_unauthorized,
    GitErrorCode.forbidden => l10n.settings_gitConfig_error_forbidden,
    GitErrorCode.notFound => l10n.settings_gitConfig_error_notFound,
    GitErrorCode.notGit => l10n.settings_gitConfig_error_notGit,
    GitErrorCode.unreachable => l10n.settings_gitConfig_error_unreachable(
      e.host ?? '?',
    ),
    GitErrorCode.untrustedCertificate =>
      l10n.settings_gitConfig_error_untrusted,
    GitErrorCode.staleTip => l10n.settings_gitConfig_error_staleTip,
    GitErrorCode.protectedBranch =>
      l10n.settings_gitConfig_error_protectedBranch(branch),
    GitErrorCode.tooLarge =>
      size == null
          ? l10n.settings_gitConfig_error_tooLargeUnknown
          : l10n.settings_gitConfig_error_tooLarge(
              (size / (1024 * 1024)).round().toString(),
            ),
    GitErrorCode.rateLimited => l10n.settings_gitConfig_error_rateLimited,
    GitErrorCode.branchHasOtherContent =>
      l10n.settings_gitConfig_error_branchHasOtherContent(branch),
    GitErrorCode.publicRepoUnencrypted =>
      l10n.settings_gitConfig_error_publicRepoUnencrypted,
    GitErrorCode.indexUnreadable =>
      l10n.settings_gitConfig_error_indexUnreadable(branch),
    GitErrorCode.server => l10n.settings_gitConfig_error_server,
    GitErrorCode.unexpected => l10n.settings_gitConfig_error_unexpected,
  };
  final reason = e.serverReason;
  return reason == null ? text : '$text ($reason)';
}
