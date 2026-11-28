import 'package:flutter/material.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_catalogue_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Manage switch for downloading newer equipment catalogue
/// releases on this device (issue #5118). Hidden in a browser, which never
/// downloads it.
class EquipmentCatalogueUpdatesTile extends ConsumerWidget {
  const EquipmentCatalogueUpdatesTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(deviceCapabilitiesProvider).isBrowser) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return SwitchListTile(
      key: const ValueKey('settings_manage_equipmentCatalogueUpdates'),
      secondary: const Icon(Icons.menu_book_outlined),
      title: Text(l10n.settings_equipmentCatalogue_title),
      subtitle: Text(l10n.settings_equipmentCatalogue_subtitle),
      value: ref.watch(equipmentCatalogueUpdatesEnabledProvider),
      onChanged: (enabled) => ref
          .read(equipmentCatalogueUpdatesEnabledProvider.notifier)
          .setEnabled(enabled),
    );
  }
}
