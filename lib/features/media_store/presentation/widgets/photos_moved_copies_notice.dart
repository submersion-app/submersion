import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/settings/presentation/providers/pending_setup_items_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Another device moved the library's photo copies to a store this device
/// is not attached to (issue #3482). Said above the Using row, whose Change
/// follows the move; a device attached nowhere gets the status line's
/// "finish setting up" instead. Dismissed per device, as on the setup card.
class PhotosMovedCopiesNotice extends ConsumerWidget {
  const PhotosMovedCopiesNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attached = ref.watch(photosCopiesProvider).value?.attached ?? false;
    final item = attached
        ? (ref.watch(pendingSetupItemsProvider).value ?? const [])
              .firstWhereOrNull(
                (i) => i.kind == SetupItemKind.mediaStoreAttach && !i.dismissed,
              )
        : null;
    if (item == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.cloud_upload_outlined),
      title: Text(l10n.settings_setUpDevice_item_attach(item.label)),
      trailing: IconButton(
        tooltip: l10n.common_action_dismiss,
        icon: const Icon(Icons.close, size: 18),
        onPressed: () async {
          final container = ProviderScope.containerOf(context, listen: false);
          await PendingSetupService.dismissKey(
            container.read(sharedPreferencesProvider),
            item.key,
          );
          container.invalidate(pendingSetupItemsProvider);
        },
      ),
    );
  }
}
