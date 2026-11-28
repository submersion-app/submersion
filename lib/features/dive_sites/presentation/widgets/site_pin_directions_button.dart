import 'package:flutter/material.dart';

import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/helpers/site_link_launcher.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Directions to a site's pin, beside its coordinates (issue #5073). Shown
/// for a site with GPS and no street address, and for one with an address
/// while the diver has switched the Contact card off: otherwise directions
/// are on that card. They go to the address when there is one.
class SitePinDirectionsButton extends ConsumerWidget {
  const SitePinDirectionsButton({super.key, required this.site});

  final DiveSite site;

  /// Whether [site] gets the button, [contactShown] being whether the page
  /// shows the Contact card.
  static bool shownFor(DiveSite site, {bool contactShown = true}) =>
      site.hasCoordinates &&
      (!contactShown || (site.address?.trim().isEmpty ?? true));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactShown = ref.watch(
      settingsProvider.select(
        (s) => s.siteDetailSections.any(
          (section) =>
              section.id == SiteDetailSectionId.contact && section.visible,
        ),
      ),
    );
    if (!shownFor(site, contactShown: contactShown)) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const ValueKey('site_location_directions'),
      icon: const Icon(Icons.directions),
      color: Theme.of(context).colorScheme.primary,
      tooltip: context.l10n.diveSites_contact_directions,
      onPressed: () => openSiteDirections(context, ref, site),
    );
  }
}
