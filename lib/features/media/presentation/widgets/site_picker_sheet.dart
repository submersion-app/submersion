import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// Lets the user pick one dive site by name. Resolves to the site id, or
/// null when dismissed.
Future<String?> showSitePickerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final async = ref.watch(sitesProvider);
        // A spinner while loading, like the dive picker: an empty list at
        // this moment would read as a blank, broken sheet.
        if (async.isLoading && !async.hasValue) {
          return const SafeArea(
            child: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final sites = async.value ?? const [];
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final site in sites)
                ListTile(
                  title: Text(site.name),
                  onTap: () => Navigator.of(sheetContext).pop(site.id),
                ),
            ],
          ),
        );
      },
    ),
  );
}
