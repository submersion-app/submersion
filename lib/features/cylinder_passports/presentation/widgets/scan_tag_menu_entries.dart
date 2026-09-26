import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The overflow-menu value that opens the cylinder tag scanner.
const scanTagMenuValue = 'scan_tag';

/// "Scan a cylinder tag" and the divider under it, first in each equipment
/// list overflow menu (issue #2335). One definition, so every menu shows the
/// same item.
List<PopupMenuEntry<String>> scanTagMenuEntries(BuildContext context) => [
  PopupMenuItem<String>(
    key: const ValueKey('equipment_menu_scanTag'),
    value: scanTagMenuValue,
    child: Row(
      children: [
        const Icon(Icons.qr_code_scanner, size: 20),
        const SizedBox(width: 12),
        // Wraps rather than overflows: some translations are long.
        Flexible(child: Text(context.l10n.passport_scan_title)),
      ],
    ),
  ),
  const PopupMenuDivider(),
];
