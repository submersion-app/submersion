import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/change_log/presentation/providers/change_log_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/byte_format.dart';

/// How much of the database the change log holds. A row under the database
/// rather than a category of its own, because those bytes are already in the
/// database's total.
class ChangeLogStorageRow extends ConsumerWidget {
  const ChangeLogStorageRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(changeLogStorageBytesProvider).value;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 32, right: 16),
      title: Text(context.l10n.changeLog_storage_label),
      trailing: bytes == null ? null : Text(formatBytes(bytes)),
    );
  }
}
