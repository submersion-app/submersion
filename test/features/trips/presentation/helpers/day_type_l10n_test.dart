import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/presentation/helpers/day_type_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Every DayType value has a label in every locale (#2845 added Travel and
/// Rest).
void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('every day type has a label in $locale', (tester) async {
      final labels = <DayType, String>{};
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              for (final type in DayType.values) {
                labels[type] = type.localizedName(context);
              }
              return const SizedBox();
            },
          ),
        ),
      );
      for (final type in DayType.values) {
        expect(labels[type], isNotEmpty, reason: '$type in $locale');
      }
      expect(
        labels.values.toSet(),
        hasLength(DayType.values.length),
        reason: 'two day types share a label in $locale',
      );
    });
  }
}
