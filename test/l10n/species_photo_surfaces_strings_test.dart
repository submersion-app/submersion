import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations_de.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  test('sighting photo count pluralizes in English', () {
    final l10n = AppLocalizationsEn();
    expect(l10n.diveLog_detail_sightingPhotos(1), '1 photo');
    expect(l10n.diveLog_detail_sightingPhotos(3), '3 photos');
  });

  test('library species facet is labelled per locale', () {
    expect(AppLocalizationsEn().media_library_filter_species, 'Species');
    expect(AppLocalizationsDe().media_library_filter_species, 'Art');
  });
}
