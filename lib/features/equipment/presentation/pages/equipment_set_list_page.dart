import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_set_list_content.dart';

class EquipmentSetListPage extends ConsumerWidget {
  const EquipmentSetListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.equipment_sets_appBar_title)),
      body: const EquipmentSetListContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/equipment/sets/new'),
        tooltip: context.l10n.equipment_sets_fabTooltip,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.equipment_sets_fab_createSet),
      ),
    );
  }
}
