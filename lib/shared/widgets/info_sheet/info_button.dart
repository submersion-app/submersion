import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';
import 'package:submersion/shared/widgets/info_sheet/info_sheet.dart';

export 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The discreet "i" at the far right of a card header.
///
/// [content] runs when the icon is tapped, not when the card builds, so the
/// sheet lists what the card shows at that moment.
class InfoButton extends StatelessWidget {
  const InfoButton({super.key, required this.title, required this.content});

  /// The card's title, read out as "About {title}".
  final String title;

  final InfoContentBuilder content;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.info_button_semantics(title);
    return IconButton(
      icon: Icon(
        Icons.info_outline,
        size: 18,
        color: Theme.of(context).colorScheme.outline,
        semanticLabel: label,
      ),
      tooltip: label,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: EdgeInsets.zero,
      onPressed: () => showInfoSheet(context, content(context)),
    );
  }
}
