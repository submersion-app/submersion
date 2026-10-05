import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('surfaceGps is a known section and present in defaults', () {
    expect(
      DiveDetailSectionId.values.contains(DiveDetailSectionId.surfaceGps),
      true,
    );
    expect(
      DiveDetailSectionConfig.defaultSections.any(
        (c) => c.id == DiveDetailSectionId.surfaceGps,
      ),
      true,
    );
  });

  // The section maps the dive site too, not only GPS fixes (issue #402), so
  // the settings list names it for both.
  test(
    'the section is listed as Location, covering the site and GPS',
    () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      const id = DiveDetailSectionId.surfaceGps;

      expect(id.displayName, 'Location');
      expect(id.localizedDisplayName(l10n), 'Location');
      expect(id.description, contains('dive site'));
      expect(id.localizedDescription(l10n), id.description);
    },
  );
}
