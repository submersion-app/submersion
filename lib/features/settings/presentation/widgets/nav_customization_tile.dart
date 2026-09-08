import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/nav/nav_order_provider.dart';

/// Settings row that opens the navigation customizer.
///
/// Its own widget because two surfaces render the Appearance section: the
/// pushed AppearancePage on narrow windows, and the inline section content in
/// the master-detail settings page. Adding the row to only one of them is how
/// the wide-screen rail ended up with no way to reach its own ordering.
class NavCustomizationTile extends ConsumerWidget {
  const NavCustomizationTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Preview whichever surface the user is actually looking at, using the
    // same 800px switch MainScaffold uses to choose rail over bottom bar.
    final destinations = ResponsiveBreakpoints.isDesktop(context)
        ? ref.watch(navRailDestinationsProvider)
        : ref.watch(navPrimaryDestinationsProvider);

    // Skip pinned Home, and the trailing More sentinel the phone list carries.
    final labels = destinations
        .skip(1)
        .where((d) => d.id != 'more')
        .take(3)
        .map((d) => d.label(context.l10n))
        .toList();

    final preview = context.l10n.settings_navCustomization_subtitlePreview(
      labels.isNotEmpty ? labels[0] : '',
      labels.length > 1 ? labels[1] : '',
      labels.length > 2 ? labels[2] : '',
    );

    return ListTile(
      leading: const FeatureAccentIcon(
        Icons.view_quilt_outlined,
        featureId: 'settings-appearance',
        surface: AccentSurface.list,
      ),
      title: Text(context.l10n.settings_navCustomization_title),
      subtitle: Text(preview),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/settings/appearance/navigation'),
    );
  }
}
