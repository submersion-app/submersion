import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/species_id/presentation/providers/species_download_prompt_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Offers the identification model to a diver who has none (issue #4773):
/// a tap opens Species identification in Settings, and the close button
/// hides the offer on this device for good. Draws nothing unless
/// [speciesDownloadPromptProvider] wants it.
///
/// [banner] fills it like the other banners at the top of a page; without
/// it, it is a plain row inside a card or sheet.
class SpeciesDownloadPrompt extends ConsumerWidget {
  const SpeciesDownloadPrompt({super.key, this.banner = false});

  final bool banner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(speciesDownloadPromptProvider)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final color = banner ? scheme.onSecondaryContainer : null;
    final tile = ListTile(
      key: const ValueKey('species_download_prompt'),
      contentPadding: banner ? null : EdgeInsets.zero,
      leading: Icon(iconForSpeciesCategory(SpeciesCategory.fish), color: color),
      title: Text(
        l10n.speciesId_downloadPrompt_title,
        style: TextStyle(color: color),
      ),
      subtitle: Text(
        l10n.speciesId_downloadPrompt_subtitle,
        style: TextStyle(color: color),
      ),
      trailing: IconButton(
        key: const ValueKey('species_download_prompt_dismiss'),
        icon: Icon(Icons.close, color: color),
        tooltip: l10n.speciesId_downloadPrompt_dismiss,
        onPressed: () => ref
            .read(speciesDownloadPromptDismissedProvider.notifier)
            .setEnabled(true),
      ),
      onTap: () => context.push('/settings/marine-life-identification'),
    );
    if (!banner) return tile;
    return Material(color: scheme.secondaryContainer, child: tile);
  }
}
