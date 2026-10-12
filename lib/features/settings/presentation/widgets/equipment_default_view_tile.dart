import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/equipment/presentation/utils/equipment_default_view_label.dart';
import 'package:submersion/features/settings/presentation/pages/equipment_default_view_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Manage row for the default equipment view (issue #2628); its
/// subtitle is the statuses the view shows.
class EquipmentDefaultViewTile extends ConsumerWidget {
  const EquipmentDefaultViewTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ListTile(
      key: const ValueKey('settings_manage_equipmentDefaultView'),
      leading: const Icon(Icons.filter_list),
      title: Text(l10n.settings_equipmentDefaultView_title),
      subtitle: Text(
        equipmentDefaultStatusesLabel(
          ref.watch(equipmentDefaultStatusesProvider),
          l10n,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(kEquipmentDefaultViewRoute),
    );
  }
}
