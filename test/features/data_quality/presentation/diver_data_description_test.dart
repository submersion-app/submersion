import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/entities/diver_data_summary.dart';
import 'package:submersion/features/data_quality/presentation/widgets/diver_data_description.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('says nothing about a dive the diver has not touched', () {
    expect(describeDiverData(const DiverDataSummary(), l10n), isNull);
  });

  test('says nothing when the dive is unknown', () {
    expect(describeDiverData(null, l10n), isNull);
  });

  test('counts read as counts and singles read as words', () {
    final text = describeDiverData(
      const DiverDataSummary(gear: 6, buddies: 2, hasNotes: true),
      l10n,
    );
    expect(text, '6 gear items · 2 buddies · notes');
  });

  test('a lone signal stands on its own', () {
    expect(
      describeDiverData(const DiverDataSummary(gear: 1), l10n),
      '1 gear item',
    );
  });

  // Every signal carriesDiverData tests has to be sayable, or the dialog
  // would fall silent on a copy the detector treats as carrying work.
  test('names each of the fourteen signals', () {
    const all = DiverDataSummary(
      gear: 1,
      weights: 2,
      buddies: 3,
      tags: 4,
      sightings: 5,
      media: 6,
      customFields: 7,
      hasNotes: true,
      hasRating: true,
      isFavorite: true,
      hasSite: true,
      hasTrip: true,
      hasDiveCenter: true,
      hasCourse: true,
    );
    expect(
      describeDiverData(all, l10n),
      '1 gear item · 2 weights · 3 buddies · 4 tags · 5 species · '
      '6 photos or videos · 7 custom fields · notes · a rating · '
      'a favorite · a site · a trip · a dive center · a course',
    );
  });
}
