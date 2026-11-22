import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('species photo strings exist in English', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(l10n.marineLife_speciesPhotos_title(3), 'Photos (3)');
    expect(l10n.marineLife_speciesPhotos_tagPhotos, 'Tag photos');
    expect(l10n.marineLife_tagPicker_confirm(1), 'Tag 1 photo');
    expect(l10n.marineLife_tagPicker_confirm(4), 'Tag 4 photos');
    expect(l10n.media_species_sheetTitle, 'Species in this photo');
    expect(l10n.media_species_sheetTitleVideo, 'Species in this video');
    expect(l10n.media_species_scanProgress('40%'), 'Looking for fish, 40%');
    expect(l10n.media_species_unnamedFish, 'Unnamed fish, tap to name');
    expect(l10n.media_species_unnamedFishLocked, 'Unnamed fish');
    expect(
      l10n.settings_speciesId_toggle,
      'Identify species when I open a photo or video',
    );
    expect(
      l10n.settings_speciesId_levelTitle,
      'How readily to suggest a species',
    );
    expect(l10n.marineLife_tagPicker_diveLabel(101), 'Dive 101');
  });

  test('species photo strings are translated in German', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('de'));

    expect(l10n.marineLife_speciesPhotos_tagPhotos, 'Fotos markieren');
    expect(l10n.marineLife_tagPicker_confirm(4), '4 Fotos markieren');
  });
}
