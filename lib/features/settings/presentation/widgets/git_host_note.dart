import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Which token to create on the host recognized in the repository address,
/// with a link to that host's documentation. Help text only: Submersion
/// connects to every host the same way.
class GitHostNote extends StatelessWidget {
  const GitHostNote({super.key, required this.hostKind});

  final GitHostKind hostKind;

  /// The host's token documentation, or null for an unrecognized host.
  static Uri? tokenDocsFor(GitHostKind kind) => switch (kind) {
    GitHostKind.github => Uri.parse(
      'https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens',
    ),
    GitHostKind.gitlab => Uri.parse(
      'https://docs.gitlab.com/user/profile/personal_access_tokens/',
    ),
    GitHostKind.bitbucket => Uri.parse(
      'https://support.atlassian.com/bitbucket-cloud/docs/using-api-tokens/',
    ),
    GitHostKind.giteaLike => Uri.parse(
      'https://forgejo.org/docs/latest/user/token-scope/',
    ),
    GitHostKind.other => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = switch (hostKind) {
      GitHostKind.github => l10n.settings_gitConfig_host_github,
      GitHostKind.gitlab => l10n.settings_gitConfig_host_gitlab,
      GitHostKind.bitbucket => l10n.settings_gitConfig_host_bitbucket,
      GitHostKind.giteaLike => l10n.settings_gitConfig_host_gitea,
      GitHostKind.other => l10n.settings_gitConfig_host_other,
    };
    final docs = tokenDocsFor(hostKind);
    return Container(
      key: const Key('git-host-note'),
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(left: BorderSide(color: scheme.secondary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: Theme.of(context).textTheme.bodySmall),
          if (docs != null)
            TextButton.icon(
              key: const Key('git-token-help'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () =>
                  launchUrl(docs, mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(l10n.settings_gitConfig_host_tokenHelp),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}
