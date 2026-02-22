import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Shows a bottom sheet with options for adding a dive:
/// - Log Dive Manually
/// - Import from Computer
///
/// [onLogManually] is called when "Log Dive Manually" is tapped.
/// "Import from Computer" navigates directly to the dive computers page.
void showAddDiveBottomSheet({
  required BuildContext context,
  required VoidCallback onLogManually,
}) {
  showModalBottomSheet(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  sheetContext.l10n.diveLog_listPage_fab_addDive,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: Text(
                  sheetContext.l10n.diveLog_listPage_bottomSheet_logManually,
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onLogManually();
                },
              ),
              ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(
                  sheetContext
                      .l10n
                      .diveLog_listPage_bottomSheet_importFromComputer,
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/dive-computers');
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
