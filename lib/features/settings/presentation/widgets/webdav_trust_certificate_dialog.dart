import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks whether to trust a certificate that failed verification. True only
/// when the user chose Trust.
Future<bool> showWebDavTrustDialog(
  BuildContext context,
  WebDavUntrustedCertificateException e,
) async {
  final l10n = context.l10n;
  final cert = e.certificate;
  final previous = e.pinnedSha256;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.gpp_maybe_outlined),
      title: Text(l10n.settings_webdavConfig_trust_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              previous == null
                  ? l10n.settings_webdavConfig_trust_body(cert.host)
                  : l10n.settings_webdavConfig_trust_changedBody(cert.host),
            ),
            const SizedBox(height: 16),
            _Field(
              label: l10n.settings_webdavConfig_trust_fingerprint,
              value: cert.formattedFingerprint,
              monospace: true,
            ),
            if (previous != null)
              _Field(
                label: l10n.settings_webdavConfig_trust_previousFingerprint,
                value: formatFingerprint(previous),
                monospace: true,
              ),
            _Field(
              label: l10n.settings_webdavConfig_trust_subject,
              value: cert.subject,
            ),
            _Field(
              label: l10n.settings_webdavConfig_trust_issuer,
              value: cert.issuer,
            ),
            // The diver's date preference, not the ambient locale (#1512).
            Consumer(
              builder: (context, ref, _) => _Field(
                label: l10n.settings_webdavConfig_trust_expires,
                value: UnitFormatter(
                  ref.watch(settingsProvider),
                ).formatDate(cert.endValidity),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          key: const Key('webdav-trust'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.settings_webdavConfig_trust_action),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          SelectableText(
            value,
            style: monospace
                ? theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
