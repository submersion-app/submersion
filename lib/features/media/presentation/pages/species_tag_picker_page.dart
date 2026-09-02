import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/domain/entities/species_tag_candidate_group.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';

/// Picks photos to tag with one species, from the dives where the diver
/// logged it. Pops with the [TagPhotosResult] after tagging, or null.
///
/// The whole page is a picker, so every tile renders in selection mode and
/// toggles on tap; one [SelectionController] keyed by media id spans the
/// per-dive groups so "Select all" and the confirm count cover them all.
class SpeciesTagPickerPage extends ConsumerStatefulWidget {
  final String speciesId;

  const SpeciesTagPickerPage({super.key, required this.speciesId});

  @override
  ConsumerState<SpeciesTagPickerPage> createState() =>
      _SpeciesTagPickerPageState();
}

class _SpeciesTagPickerPageState extends ConsumerState<SpeciesTagPickerPage> {
  final SelectionController _selection = SelectionController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selection.enterExplicit();
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groupsAsync = ref.watch(
      speciesTagCandidatesProvider(widget.speciesId),
    );
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final allIds = [
      for (final group
          in groupsAsync.value ?? const <SpeciesTagCandidateGroup>[])
        for (final item in group.items) item.id,
    ];

    return ValueListenableBuilder<SelectionState>(
      valueListenable: _selection,
      builder: (context, selection, _) {
        final checked = selection.checkedIds;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.marineLife_tagPicker_title),
            actions: [
              if (allIds.isNotEmpty)
                TextButton(
                  key: const ValueKey('tag_picker_select_all'),
                  onPressed: () => _selection.selectAll(allIds),
                  child: Text(l10n.marineLife_tagPicker_selectAll),
                ),
            ],
          ),
          body: groupsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('$error')),
            data: (groups) {
              if (groups.isEmpty) {
                return _EmptyState(l10n: l10n);
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final group in groups) ...[
                    _GroupHeader(group: group, units: units, l10n: l10n),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: group.items.length,
                      itemBuilder: (context, index) {
                        final item = group.items[index];
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _selection.toggle(item.id),
                          child: MediaThumbnailTile(
                            item: item,
                            settings: settings,
                            isSelectionMode: true,
                            isSelected: checked.contains(item.id),
                            semanticsLabel:
                                l10n.marineLife_speciesPhotos_thumbnailLabel,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              );
            },
          ),
          bottomNavigationBar: allIds.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      key: const ValueKey('tag_picker_confirm'),
                      onPressed: checked.isEmpty || _busy
                          ? null
                          : () => _confirm(checked.toList()),
                      child: Text(
                        l10n.marineLife_tagPicker_confirm(checked.length),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Future<void> _confirm(List<String> mediaIds) async {
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(speciesTaggingServiceProvider)
          .tagPhotos(mediaIds: mediaIds, speciesId: widget.speciesId);
      if (mounted) Navigator.of(context).pop(result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _GroupHeader extends StatelessWidget {
  final SpeciesTagCandidateGroup group;
  final UnitFormatter units;
  final AppLocalizations l10n;

  const _GroupHeader({
    required this.group,
    required this.units,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final number = group.diveNumber;
    final parts = [
      if (number != null) l10n.marineLife_tagPicker_diveLabel(number),
      units.formatDate(group.diveDateTime),
      group.siteName ?? l10n.marineLife_speciesDetail_unknownSite,
    ];
    return Text(
      parts.join(' · '),
      style: Theme.of(context).textTheme.titleSmall,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: theme.colorScheme.onSurface.withAlpha(77),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.marineLife_tagPicker_empty,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.marineLife_tagPicker_emptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(128),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
