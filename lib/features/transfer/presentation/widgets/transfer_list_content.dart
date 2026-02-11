import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Transfer section data model.
class TransferSection {
  final String id;
  final IconData icon;
  final String Function(BuildContext) titleBuilder;
  final String Function(BuildContext) subtitleBuilder;
  final Color? color;

  const TransferSection({
    required this.id,
    required this.icon,
    required this.titleBuilder,
    required this.subtitleBuilder,
    this.color,
  });
}

/// List of all transfer sections.
final transferSections = [
  TransferSection(
    id: 'import',
    icon: Icons.file_download,
    titleBuilder: (context) => context.l10n.transfer_section_importTitle,
    subtitleBuilder: (context) => context.l10n.transfer_section_importSubtitle,
  ),
  TransferSection(
    id: 'export',
    icon: Icons.file_upload,
    titleBuilder: (context) => context.l10n.transfer_section_exportTitle,
    subtitleBuilder: (context) => context.l10n.transfer_section_exportSubtitle,
  ),
  TransferSection(
    id: 'computers',
    icon: Icons.bluetooth,
    titleBuilder: (context) => context.l10n.transfer_section_computersTitle,
    subtitleBuilder: (context) =>
        context.l10n.transfer_section_computersSubtitle,
  ),
];

/// Content widget for the transfer section list, used in master-detail layout.
class TransferListContent extends StatelessWidget {
  final void Function(String?)? onItemSelected;
  final String? selectedId;
  final bool showAppBar;

  const TransferListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(title: Text(context.l10n.transfer_appBar_title))
          : PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                color: colorScheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.transfer_appBar_title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: transferSections.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final section = transferSections[index];
          final isSelected = selectedId == section.id;

          return _TransferSectionTile(
            section: section,
            isSelected: isSelected,
            onTap: () {
              if (onItemSelected != null) {
                onItemSelected!(section.id);
              }
            },
          );
        },
      ),
    );
  }
}

class _TransferSectionTile extends StatelessWidget {
  final TransferSection section;
  final bool isSelected;
  final VoidCallback onTap;

  const _TransferSectionTile({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = section.color ?? colorScheme.primary;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      child: ListTile(
        leading: ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(section.icon, color: color, size: 24),
          ),
        ),
        title: Text(
          section.titleBuilder(context),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          section.subtitleBuilder(context),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: ExcludeSemantics(
          child: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
