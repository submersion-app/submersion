import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/pushed_route.dart';
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
      // Colours the leading icon and both lines; the close button's icon
      // takes its colour from the button, so it is given its own.
      iconColor: color,
      textColor: color,
      leading: Icon(iconForSpeciesCategory(SpeciesCategory.fish)),
      title: Text(
        visionVideoRuns(defaultTargetPlatform)
            ? l10n.speciesId_downloadPrompt_title
            : l10n.speciesId_downloadPrompt_titlePhotos,
      ),
      subtitle: Text(l10n.speciesId_downloadPrompt_subtitle),
      trailing: IconButton(
        key: const ValueKey('species_download_prompt_dismiss'),
        icon: Icon(Icons.close, color: color),
        tooltip: l10n.speciesId_downloadPrompt_dismiss,
        onPressed: () => ref
            .read(speciesDownloadPromptDismissedNotifierProvider.notifier)
            .setEnabled(true),
      ),
      onTap: () => _open(context),
    );
    if (!banner) return tile;
    return Material(color: scheme.secondaryContainer, child: tile);
  }

  /// Opens Species identification. From the photo viewer's species sheet,
  /// both are pushed above the router's page, so they close first; a viewer
  /// holding unsaved changes is asked instead and nothing opens.
  void _open(BuildContext context) {
    final router = GoRouter.of(context);
    if (!closeRoutesAboveRouterPage(Navigator.of(context))) return;
    router.push('/settings/marine-life-identification');
  }
}
