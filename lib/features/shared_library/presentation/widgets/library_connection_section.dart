import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/features/shared_library/presentation/providers/library_connection_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where this device reaches the library: the storage account and folder,
/// and the way to point it elsewhere (issue #3389). Any member may change
/// it, since it changes nothing beyond this device.
class LibraryConnectionSection extends ConsumerWidget {
  const LibraryConnectionSection({super.key, required this.library});

  final SharedLibrary library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // .value keeps the last details through a reload rather than blanking
    // the tiles for a frame.
    final details = ref
        .watch(libraryConnectionDetailsProvider(library.id))
        .value;
    final account = details?.account;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
          child: Text(
            l10n.sharedLibrary_connection_title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        if (details != null) ...[
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: Text(
              account?.displayName ??
                  l10n.sharedLibrary_connection_accountMissing,
              style: account == null
                  ? TextStyle(color: theme.colorScheme.error)
                  : null,
            ),
            subtitle: switch (account == null
                ? null
                : _kindLine(l10n, account.kind, details)) {
              final String line => Text(line),
              null => null,
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(l10n.sharedLibrary_connection_folder),
            subtitle: Text(details.folder),
          ),
        ],
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonal(
              onPressed: () => context.pushSettingsPage(
                '/settings/shared-libraries/${library.id}/connection',
              ),
              child: Text(l10n.sharedLibrary_connection_change),
            ),
          ),
        ),
      ],
    );
  }

  static String? _kindLine(
    AppLocalizations l10n,
    AccountKind kind,
    LibraryConnectionDetails details,
  ) => switch (kind) {
    AccountKind.s3 when details.bucket != null =>
      l10n.sharedLibrary_connection_s3Bucket(details.bucket!),
    AccountKind.s3 => l10n.sharedLibrary_connection_s3,
    AccountKind.webdav when details.server != null =>
      l10n.sharedLibrary_connection_webdavServer(details.server!),
    AccountKind.webdav => l10n.sharedLibrary_connection_webdav,
    _ => null,
  };
}
