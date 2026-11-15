import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_landmarks.dart';
import 'package:submersion/features/insights/presentation/formatters/vertical_landmark_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Landmark names on the scale (issue #4569).
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('a named landmark reads its name', () {
    expect(
      verticalLandmarkName(
        l10n,
        const VerticalLandmark(VerticalLandmarkId.everest, 8849),
      ),
      'Mount Everest',
    );
    expect(
      verticalLandmarkName(
        l10n,
        const VerticalLandmark(VerticalLandmarkId.titanic, 3800),
      ),
      'Titanic',
    );
  });

  test('a multiple reads as a count of its base', () {
    expect(
      verticalLandmarkName(
        l10n,
        const VerticalLandmark(
          VerticalLandmarkId.challengerDeep,
          21870,
          multiple: 2,
        ),
      ),
      '2 × Challenger Deep',
    );
  });

  test('every landmark has a name', () {
    for (final id in VerticalLandmarkId.values) {
      expect(
        verticalLandmarkName(l10n, VerticalLandmark(id, 1)),
        isNotEmpty,
        reason: id.name,
      );
    }
  });
}
