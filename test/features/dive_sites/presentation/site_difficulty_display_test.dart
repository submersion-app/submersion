import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/site_difficulty_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('every difficulty has an English label', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(SiteDifficulty.beginner.localizedName(l10n), 'Beginner');
    expect(SiteDifficulty.intermediate.localizedName(l10n), 'Intermediate');
    expect(SiteDifficulty.advanced.localizedName(l10n), 'Advanced');
    expect(SiteDifficulty.technical.localizedName(l10n), 'Technical');
  });
}
