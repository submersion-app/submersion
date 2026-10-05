import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/presentation/helpers/site_attachment_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks which category to put the selected attachments in (issue #1039).
///
/// The result wraps the category so that choosing Uncategorized (a null
/// category) is distinguishable from dismissing the picker (a null result).
Future<({SiteAttachmentCategory? category})?> showSiteCategoryPicker(
  BuildContext context,
) => showModalBottomSheet<({SiteAttachmentCategory? category})>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (sheetContext) {
    final l10n = sheetContext.l10n;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              l10n.media_siteAttachment_setCategory,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          for (final category in <SiteAttachmentCategory?>[
            ...SiteAttachmentCategory.values,
            null,
          ])
            ListTile(
              title: Text(category.label(l10n)),
              onTap: () => Navigator.of(sheetContext).pop((category: category)),
            ),
        ],
      ),
    );
  },
);
