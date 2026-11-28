import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/domain/hosted_web_site.dart';
import 'package:submersion/features/auto_update/presentation/providers/hosted_web_site_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The About card's link from one of Submersion's own web sites to the other
/// (issue #4481): the stable site offers the beta site and the beta site
/// offers the stable site. Each keeps its own library in the browser, which
/// the subtitle says, since an empty logbook on the other site is the
/// surprise. Builds nothing anywhere else: a native build or a self-hosted
/// copy.
///
/// A divider comes first, so the row slots into the card's list.
class HostedWebSiteTile extends ConsumerWidget {
  const HostedWebSiteTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final site = ref.watch(hostedWebSiteProvider);
    final target = site.other;
    final address = target?.uri;
    if (target == null || address == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final toBeta = target == HostedWebSite.beta;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        ListTile(
          leading: Icon(toBeta ? Icons.science_outlined : Icons.undo),
          title: Text(
            toBeta
                ? l10n.settings_updates_tryBetaWeb
                : l10n.settings_updates_useStableWeb,
          ),
          subtitle: Text(
            toBeta
                ? l10n.settings_updates_tryBetaWebSubtitle(address.host)
                : l10n.settings_updates_useStableWebSubtitle(address.host),
          ),
          // A new tab, so the page the diver is on keeps its library open.
          onTap: () => launchUrl(address, webOnlyWindowName: '_blank'),
        ),
      ],
    );
  }
}
