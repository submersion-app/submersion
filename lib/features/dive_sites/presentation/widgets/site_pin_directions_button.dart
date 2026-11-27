import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/helpers/site_link_launcher.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Directions to a site's pin, beside its coordinates (issue #5073). Shown
/// only for a site with GPS and no street address: one with an address has
/// directions on its Contact card instead.
class SitePinDirectionsButton extends ConsumerWidget {
  const SitePinDirectionsButton({super.key, required this.site});

  final DiveSite site;

  /// Whether [site] gets the button.
  static bool shownFor(DiveSite site) =>
      site.hasCoordinates && (site.address?.trim().isEmpty ?? true);

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: const ValueKey('site_location_directions'),
    icon: const Icon(Icons.directions),
    color: Theme.of(context).colorScheme.primary,
    tooltip: context.l10n.diveSites_contact_directions,
    onPressed: () => openSiteDirections(context, ref, site),
  );
}
