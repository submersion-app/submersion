import 'package:flutter/material.dart';

import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Tag out of date" with Rewrite (NFC) and Reprint (label), shared by the
/// cylinder and gear Tag cards (cylinder spec 6.6, gear tag spec 6.5).
/// [onReprint] gets the Reprint button's own context, so the share sheet
/// can point at it. A null callback disables its button.
class TagStaleBanner extends StatelessWidget {
  const TagStaleBanner({
    super.key,
    required this.rewriteKey,
    required this.reprintKey,
    this.onRewrite,
    this.onReprint,
  });

  final Key rewriteKey;
  final Key reprintKey;
  final VoidCallback? onRewrite;
  final void Function(BuildContext buttonContext)? onReprint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final warn = StatusColors.of(context).warn;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warn.container,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: warn.onContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.passport_tag_stale,
                  style: TextStyle(color: warn.onContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                key: rewriteKey,
                onPressed: onRewrite,
                child: Text(l10n.passport_nfc_rewrite),
              ),
              Builder(
                builder: (buttonContext) => TextButton(
                  key: reprintKey,
                  onPressed: onReprint == null
                      ? null
                      : () => onReprint!(buttonContext),
                  child: Text(l10n.passport_nfc_reprint),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
