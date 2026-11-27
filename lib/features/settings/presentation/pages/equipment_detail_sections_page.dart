import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/equipment_detail_sections.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings for which cards a gear item's page shows, and in what order
/// (issue #4975).
///
/// Lists every card, also those only some types of gear have: one order
/// serves every type, and a card a type lacks is skipped where it sits.
class EquipmentDetailSectionsPage extends ConsumerWidget {
  const EquipmentDetailSectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(
      settingsProvider.select((s) => s.equipmentDetailSections),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_equipmentDetailSections_title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') {
                ref
                    .read(settingsProvider.notifier)
                    .resetEquipmentDetailSections();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reset',
                child: Text(
                  context.l10n.settings_diveDetailSections_resetToDefault,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              context.l10n.settings_diveDetailSections_configurableSections,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: sections.length,
              onReorderItem: (oldIndex, newIndex) => ref
                  .read(settingsProvider.notifier)
                  .setEquipmentDetailSections(
                    EquipmentDetailSectionConfig.moveRenderedSection(
                      sections,
                      [for (final s in sections) s.id],
                      oldIndex,
                      newIndex,
                    ),
                  ),
              itemBuilder: (context, index) {
                final section = sections[index];
                return _SectionTile(
                  key: ValueKey(section.id),
                  section: section,
                  index: index,
                  onToggle: (visible) => ref
                      .read(settingsProvider.notifier)
                      .setEquipmentDetailSections([
                        for (final s in sections)
                          if (s.id == section.id)
                            s.copyWith(visible: visible)
                          else
                            s,
                      ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    super.key,
    required this.section,
    required this.index,
    required this.onToggle,
  });

  final EquipmentDetailSectionConfig section;
  final int index;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: section.visible ? 1.0 : 0.5,
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(
          section.id.localizedDisplayName(context.l10n),
          style: theme.textTheme.bodyLarge,
        ),
        subtitle: Text(
          section.id.localizedDescription(context.l10n),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(value: section.visible, onChanged: onToggle),
      ),
    );
  }
}
