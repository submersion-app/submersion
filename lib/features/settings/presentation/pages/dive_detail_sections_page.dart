import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class DiveDetailSectionsPage extends ConsumerWidget {
  const DiveDetailSectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(
      settingsProvider.select((s) => s.diveDetailSections),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_diveDetailSections_title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') {
                ref.read(settingsProvider.notifier).resetDiveDetailSections();
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              context.l10n.settings_diveDetailSections_fixedSections,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
              onReorder: (oldIndex, newIndex) {
                _onReorder(ref, sections, oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final section = sections[index];
                return _SectionTile(
                  key: ValueKey(section.id),
                  section: section,
                  index: index,
                  onToggle: (visible) {
                    _onToggle(ref, sections, index, visible);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onReorder(
    WidgetRef ref,
    List<DiveDetailSectionConfig> sections,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex > oldIndex) newIndex--;
    final updated = List.of(sections);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    ref.read(settingsProvider.notifier).setDiveDetailSections(updated);
  }

  void _onToggle(
    WidgetRef ref,
    List<DiveDetailSectionConfig> sections,
    int index,
    bool visible,
  ) {
    final updated = List.of(sections);
    updated[index] = updated[index].copyWith(visible: visible);
    ref.read(settingsProvider.notifier).setDiveDetailSections(updated);
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    super.key,
    required this.section,
    required this.index,
    required this.onToggle,
  });

  final DiveDetailSectionConfig section;
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
