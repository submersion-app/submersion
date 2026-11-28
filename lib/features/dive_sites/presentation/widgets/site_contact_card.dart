import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/util/web_link.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/helpers/site_link_launcher.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

/// A site's address, phone, email and website (issue #5073): tap to
/// navigate, call, mail or open, long-press to copy.
class SiteContactCard extends ConsumerWidget {
  const SiteContactCard({super.key, required this.site});

  final DiveSite site;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    String? set(String? value) =>
        value != null && value.trim().isNotEmpty ? value.trim() : null;
    final address = set(site.address);
    final phone = set(site.phone);
    final email = set(site.email);
    final website = set(site.website);
    final webUri = parseWebLink(website);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecordCardHeader(
              title: l10n.diveSites_detail_section_contact,
              leading: Icon(
                Icons.contact_phone_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            if (address != null)
              _ContactRow(
                key: const ValueKey('site_contact_address'),
                icon: Icons.place_outlined,
                label: l10n.diveSites_contact_address,
                value: address,
                onTap: () => openSiteDirections(context, ref, site),
                trailing: IconButton(
                  key: const ValueKey('site_contact_directions'),
                  icon: const Icon(Icons.directions),
                  color: colorScheme.primary,
                  tooltip: l10n.diveSites_contact_directions,
                  onPressed: () => openSiteDirections(context, ref, site),
                ),
              ),
            if (phone != null)
              _ContactRow(
                key: const ValueKey('site_contact_phone'),
                icon: Icons.phone_outlined,
                label: l10n.diveSites_contact_phone,
                value: phone,
                onTap: () => openSiteLink(context, ref, phoneUri(phone)),
              ),
            if (email != null)
              _ContactRow(
                key: const ValueKey('site_contact_email'),
                icon: Icons.email_outlined,
                label: l10n.diveSites_contact_email,
                value: email,
                onTap: () => openSiteLink(
                  context,
                  ref,
                  Uri(scheme: 'mailto', path: email),
                ),
              ),
            if (website != null)
              _ContactRow(
                key: const ValueKey('site_contact_website'),
                icon: Icons.language_outlined,
                label: l10n.diveSites_contact_website,
                value: webUri == null ? website : displayWebsite(website),
                copyText: website,
                // Only a web address opens: the value can arrive from a
                // sync, an import or an agent, not only from typing.
                onTap: webUri == null
                    ? null
                    : () => openSiteLink(context, ref, webUri),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.copyText,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;

  /// What a long press copies; [value] when null.
  final String? copyText;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: copyText ?? value));
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(context.l10n.common_snackbar_copiedToClipboard),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                icon,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onTap == null ? null : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
