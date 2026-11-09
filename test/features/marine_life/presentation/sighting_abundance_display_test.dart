import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/presentation/sighting_abundance_display.dart';
import 'package:submersion/features/marine_life/presentation/widgets/sighting_amount_badge.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final AppLocalizations l10n = AppLocalizationsEn();

  SightingAmount amount(SightingAbundance a, [int count = 1]) =>
      (abundance: a, count: count);

  group('sightingAmountLabel', () {
    test('Seen has no label', () {
      expect(sightingAmountLabel(l10n, amount(SightingAbundance.seen)), isNull);
    });

    test('an exact count shows x<n>, one included', () {
      expect(
        sightingAmountLabel(l10n, amount(SightingAbundance.exact, 1)),
        'x1',
      );
      expect(
        sightingAmountLabel(l10n, amount(SightingAbundance.exact, 12)),
        'x12',
      );
    });

    test('a REEF group shows its name', () {
      expect(
        sightingAmountLabel(l10n, amount(SightingAbundance.single)),
        'Single',
      );
      expect(sightingAmountLabel(l10n, amount(SightingAbundance.few)), 'Few');
      expect(sightingAmountLabel(l10n, amount(SightingAbundance.many)), 'Many');
      expect(
        sightingAmountLabel(l10n, amount(SightingAbundance.abundant)),
        'Abundant',
      );
    });
  });

  test('every value has a chip name', () {
    expect(
      SightingAbundance.values.map((a) => sightingAbundanceName(l10n, a)),
      ['Seen', 'Single', 'Few', 'Many', 'Abundant', 'Exact'],
    );
  });

  group('SightingAmountBadge', () {
    Future<void> pump(WidgetTester tester, SightingAmount value) =>
        tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(body: SightingAmountBadge(amount: value)),
          ),
        );

    testWidgets('draws nothing for Seen', (tester) async {
      await pump(tester, amount(SightingAbundance.seen));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('draws the label for an exact count', (tester) async {
      await pump(tester, amount(SightingAbundance.exact, 3));
      expect(find.text('x3'), findsOneWidget);
    });

    testWidgets('draws the group name', (tester) async {
      await pump(tester, amount(SightingAbundance.abundant));
      expect(find.text('Abundant'), findsOneWidget);
    });
  });
}
