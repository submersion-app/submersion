import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_protection.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One row of the reef section: marine protected area identity.
///
/// Activity permissions are intentionally absent. The source encodes them as
/// integers with no published codebook, so divers are sent to the
/// authoritative page rather than shown a guess.
class ReefProtectionCard extends StatelessWidget {
  final ReefPart<List<ReefProtection>> part;

  const ReefProtectionCard({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (part.status == ReefDataStatus.unavailable) {
      return ListTile(
        leading: Icon(Icons.shield_outlined, color: scheme.primary),
        title: Text(
          context.l10n.reef_protection_title,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(context.l10n.reef_protection_unavailable),
        dense: true,
      );
    }
    if (part.status == ReefDataStatus.empty) {
      return ListTile(
        leading: Icon(Icons.shield_outlined, color: scheme.primary),
        title: Text(
          context.l10n.reef_protection_title,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(context.l10n.reef_protection_none),
        dense: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final area in part.value!)
          ListTile(
            leading: Icon(Icons.shield_outlined, color: scheme.primary),
            title: Text(area.siteName, style: theme.textTheme.titleSmall),
            subtitle: Text(_subtitle(context, area)),
            trailing: _regulationsButton(context, area),
            dense: true,
          ),
      ],
    );
  }

  /// The link comes from a remote service, so a malformed value must not throw
  /// out of the button callback. An unparseable link renders no button rather
  /// than one that crashes on tap.
  Widget? _regulationsButton(BuildContext context, ReefProtection area) {
    final raw = area.navigatorLink;
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) return null;

    return TextButton(
      onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      child: Text(context.l10n.reef_protection_viewRegulations),
    );
  }

  String _subtitle(BuildContext context, ReefProtection area) {
    final parts = <String>[];
    if (area.country != null && area.country!.isNotEmpty) {
      parts.add(area.country!);
    }
    if (area.iucnCategory != null && area.iucnCategory!.isNotEmpty) {
      parts.add(context.l10n.reef_protection_iucn(area.iucnCategory!));
    }
    return parts.join(' - ');
  }
}
