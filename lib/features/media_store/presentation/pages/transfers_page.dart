import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/widgets/transfers_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Queue visibility (design spec section 9): active, waiting, and failed
/// transfers with per-entry retry and a clear-completed action. The list
/// itself lives in [TransfersView], shared with the Media console.
class TransfersPage extends ConsumerWidget {
  const TransfersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_mediaStorage_transfers_title),
        actions: [
          IconButton(
            key: const Key('transfers-clear-done'),
            tooltip: l10n.settings_mediaStorage_transfers_clearCompleted,
            icon: const Icon(Icons.clear_all),
            onPressed: () =>
                ref.read(mediaTransferQueueRepositoryProvider).deleteDone(),
          ),
        ],
      ),
      body: const TransfersView(),
    );
  }
}
