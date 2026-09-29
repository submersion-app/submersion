import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/explore/domain/compiled_query.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/presentation/chip_labeler.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The understood row: one InputChip per compiled chip. Tap opens the filter
/// sheet on the Explore filter; the delete icon drops the clause.
class ExploreUnderstoodRow extends ConsumerWidget {
  const ExploreUnderstoodRow({super.key, required this.compiled});
  final CompiledQuery compiled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compiled.chips.isEmpty) return const SizedBox.shrink();
    final labeler = ChipLabeler(
      context.l10n,
      UnitFormatter(ref.watch(settingsProvider)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.explore_understood_title,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final chip in compiled.chips)
              // Removable, not editable in place. The sentence's parse is the
              // single source of truth and the filter is derived from it, so
              // an edit made in the filter sheet could not be reflected back
              // into the chips and would be silently discarded by the next
              // chip removal. Editing happens after a handoff, where the list
              // owns its own filter.
              InputChip(
                label: Text(labeler.label(chip.payload)),
                onDeleted: () =>
                    ref.read(exploreQueryProvider.notifier).removeChip(chip),
                deleteIcon: const Icon(Icons.close, size: 16),
              ),
          ],
        ),
      ],
    );
  }
}

/// Unresolved mentions (tap to pick a candidate) and unplaced words (plain,
/// with the reason as tooltip).
class ExploreAttentionRow extends ConsumerWidget {
  const ExploreAttentionRow({super.key, required this.compiled});
  final CompiledQuery compiled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compiled.unresolved.isEmpty && compiled.unplaced.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.explore_needsAttention_title,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final u in compiled.unresolved)
              ActionChip(
                avatar: const Icon(Icons.help_outline, size: 16),
                label: Text(u.mention.text),
                onPressed: () => _pick(context, ref, u),
              ),
            for (final w in compiled.unplaced)
              Tooltip(
                message: _reason(l10n, w.reason) ?? '',
                child: Chip(label: Text(w.text)),
              ),
          ],
        ),
      ],
    );
  }

  static String? _reason(AppLocalizations l10n, String? reason) =>
      switch (reason) {
        'invalid' => l10n.explore_unplaced_reason_invalid,
        'noAxis' => l10n.explore_unplaced_reason_noAxis,
        'outOfRange' => l10n.explore_unplaced_reason_outOfRange,
        'unknownField' => l10n.explore_unplaced_reason_unknownField,
        'unknownTime' => l10n.explore_unplaced_reason_unknownTime,
        'subjectNotSupported' => l10n.explore_subjectNotSupported,
        _ => null,
      };

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    UnresolvedMention u,
  ) async {
    final l10n = context.l10n;
    final chosen = await showModalBottomSheet<NameEntry>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(l10n.explore_pickCandidate_title(u.mention.text)),
            ),
            if (u.candidates.isEmpty)
              ListTile(subtitle: Text(l10n.explore_unresolved_noCandidates)),
            for (final c in u.candidates)
              ListTile(
                title: Text(c.label),
                onTap: () => Navigator.of(ctx).pop(c),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      ref.read(exploreQueryProvider.notifier).resolveWith(u.index, chosen);
    }
  }
}
