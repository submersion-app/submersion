import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/presentation/providers/species_download_prompt_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_download_prompt.dart';

/// The identification model offer at the top of Home (issue #4881), for a
/// diver who would otherwise never hear of it. Draws nothing unless
/// [homeSpeciesBannerProvider] wants it; the offer itself, its tap and its
/// dismiss are [SpeciesDownloadPrompt]'s.
class HomeSpeciesBanner extends ConsumerWidget {
  const HomeSpeciesBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(homeSpeciesBannerProvider)) return const SizedBox.shrink();
    return const SpeciesDownloadPrompt(banner: true);
  }
}
