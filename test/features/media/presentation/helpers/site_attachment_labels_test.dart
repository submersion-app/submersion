import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/presentation/helpers/site_attachment_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('every category, uncategorized and size has an English label', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      [
        for (final c in SiteAttachmentCategory.values) c.label(l10n),
        (null as SiteAttachmentCategory?).label(l10n),
      ],
      [
        'Site map',
        'Parking',
        'Access and entry',
        'Anchorage and mooring',
        'Underwater',
        'General',
        'Uncategorized',
      ],
    );
    expect(AttachmentDisplaySize.large.label(l10n), 'Large');
    expect(AttachmentDisplaySize.tile.label(l10n), 'Tile');
  });

  test('every locale translates the category labels', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(
        SiteAttachmentCategory.siteMap.label(l10n),
        isNot(SiteAttachmentCategory.siteMap.label(en)),
        reason: locale.languageCode,
      );
    }
  });
}
