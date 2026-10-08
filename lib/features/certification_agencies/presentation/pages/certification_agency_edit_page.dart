import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';
import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/agency_swatch.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/certification_delete_dialogs.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/certification_level_dialog.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/custom_agency_dialog.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/fab_clearance.dart';

/// One agency's certifications (issue #690). Built-in rungs are read-only;
/// the viewer's own custom rungs can be reordered, edited and deleted. The
/// owner of a custom agency edits its name, colour and sharing from the app
/// bar; another diver's shared agency is read-only.
class CertificationAgencyEditPage extends ConsumerWidget {
  const CertificationAgencyEditPage({super.key, required this.agencyId});

  /// A built-in enum name or a custom agency id.
  final String agencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final catalog = ref.watch(certificationCatalogSyncProvider);
    final entry = catalog.agency(agencyId);
    final ownsAgency = catalog.canEditAgency(agencyId);
    // Certifications can be added to a built-in agency or to one's own; a
    // custom agency's levels belong to its owner.
    final canAdd = entry.isBuiltIn || ownsAgency;
    final custom = entry.custom;

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.localizedName(l10n)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: l10n.common_action_back,
        ),
        actions: [
          if (ownsAgency && custom != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.common_action_edit,
              onPressed: () =>
                  showCustomAgencyDialog(context, existing: custom),
            ),
        ],
      ),
      body: ListView(
        padding: kFabListPadding,
        children: [
          _AgencyHeader(entry: entry),
          if (entry.isBuiltIn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.certificationAgencies_editor_builtInHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          _LevelSection(
            title: l10n.certifications_edit_group_progression,
            agencyId: agencyId,
            catalog: catalog,
            levels: catalog.ladderFor(agencyId),
            reorderable: true,
          ),
          _LevelSection(
            title: l10n.certifications_edit_group_specialties,
            agencyId: agencyId,
            catalog: catalog,
            levels: catalog.specialtiesFor(agencyId),
            reorderable: false,
          ),
          if (canAdd)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(
                    l10n.certificationAgencies_editor_addCertification,
                  ),
                  onPressed: () =>
                      showCertificationLevelDialog(context, agencyId: agencyId),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The agency's card gradient with its name: the live preview of a custom
/// agency's colour.
class _AgencyHeader extends StatelessWidget {
  const _AgencyHeader({required this.entry});

  final AgencyEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [entry.primaryColor, entry.secondaryColor],
        ),
      ),
      child: Row(
        children: [
          AgencySwatch(
            primary: Colors.white.withValues(alpha: 0.9),
            secondary: Colors.white.withValues(alpha: 0.6),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.localizedName(context.l10n),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelSection extends ConsumerWidget {
  const _LevelSection({
    required this.title,
    required this.agencyId,
    required this.catalog,
    required this.levels,
    required this.reorderable,
  });

  final String title;
  final String agencyId;
  final CertificationCatalog catalog;
  final List<LevelEntry> levels;
  final bool reorderable;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CustomCertificationLevel level,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.common_error_tryAgain;
    final repo = ref.read(customCertificationRepositoryProvider);
    try {
      // A certification in use is refused up front, not after a
      // confirmation; the delete checks again in case that changes.
      final used = await repo.usage(level.id);
      if (!context.mounted) return;
      if (used.isUsed) {
        await showCertificationDeleteRefusal(context, used);
        return;
      }
      if (!await confirmCertificationDelete(context, level.name)) return;
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return;
      final refused = await repo.deleteLevel(level.id, actingDiverId: diverId);
      if (refused != null && context.mounted) {
        await showCertificationDeleteRefusal(context, refused);
      }
    } catch (_) {
      // Logged by the repository; tell the diver it did not happen.
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    List<String> ids,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.common_error_tryAgain;
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return;
      await ref
          .read(customCertificationRepositoryProvider)
          .reorderProgression(agencyId, ids, actingDiverId: diverId);
    } catch (_) {
      // The order on screen comes from the catalog, which did not change.
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  Widget _ownTile(
    BuildContext context,
    WidgetRef ref,
    CustomCertificationLevel level, {
    Widget? leading,
  }) {
    final l10n = context.l10n;
    return ListTile(
      key: ValueKey('level-${level.id}'),
      leading: leading,
      title: Text(level.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.common_action_edit,
            onPressed: () => showCertificationLevelDialog(
              context,
              agencyId: agencyId,
              existing: level,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.common_action_delete,
            onPressed: () => _delete(context, ref, level),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final builtIn = levels.where((l) => l.isBuiltIn).toList();
    final own = [
      for (final l in levels)
        if (l.custom != null && catalog.canEditLevel(l.id)) l.custom!,
    ];
    final others = levels
        .where((l) => l.custom != null && !catalog.canEditLevel(l.id))
        .toList();
    if (builtIn.isEmpty && own.isEmpty && others.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        for (final l in builtIn)
          ListTile(enabled: false, title: Text(l.localizedName(l10n))),
        if (reorderable && own.length > 1)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (oldIndex, newIndex) {
              final ids = [for (final l in own) l.id];
              ids.insert(newIndex, ids.removeAt(oldIndex));
              _reorder(context, ref, ids);
            },
            children: [
              for (var i = 0; i < own.length; i++)
                _ownTile(
                  context,
                  ref,
                  own[i],
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_handle),
                  ),
                ),
            ],
          )
        else
          for (final l in own) _ownTile(context, ref, l),
        for (final l in others) ListTile(title: Text(l.localizedName(l10n))),
      ],
    );
  }
}
