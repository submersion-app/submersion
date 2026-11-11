import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/dense_site_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/country_flag.dart';

import '../../../../helpers/test_app.dart';

void main() {
  group('DenseSiteListTile', () {
    testWidgets('renders name, location, and dive count', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseSiteListTile(
            name: 'Blue Corner Wall',
            location: 'Palau, Micronesia',
            diveCount: 12,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Blue Corner Wall'), findsOneWidget);
      expect(find.text('Palau, Micronesia'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('shows checkbox in selection mode', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseSiteListTile(
            name: 'Blue Corner Wall',
            diveCount: 5,
            isSelectionMode: true,
            isSelected: true,
            onTap: () {},
          ),
        ),
      );

      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('handles null location gracefully', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseSiteListTile(
            name: 'Unknown Site',
            diveCount: 0,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Unknown Site'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('country flag (issue #4426)', () {
    const site = DiveSite(
      id: 's1',
      name: 'Blue Corner Wall',
      country: 'Micronesia',
      region: 'Palau',
    );

    Future<void> pumpTile(WidgetTester tester, {bool flags = true}) =>
        tester.pumpWidget(
          testApp(
            overrides: [showCountryFlagsProvider.overrideWithValue(flags)],
            child: DenseSiteListTile(
              name: site.name,
              site: site,
              location: 'Palau, Micronesia',
              diveCount: 12,
              onTap: () {},
            ),
          ),
        );

    testWidgets('the location carries the country flag', (tester) async {
      await pumpTile(tester);
      expect(tester.widget<CountryFlag>(find.byType(CountryFlag)).code, 'FM');
      expect(find.text('Palau, Micronesia'), findsOneWidget);
    });

    testWidgets('no flag when flags are off', (tester) async {
      await pumpTile(tester, flags: false);
      expect(find.byType(CountryFlag), findsNothing);
    });

    testWidgets('no flag without a site', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [showCountryFlagsProvider.overrideWithValue(true)],
          child: DenseSiteListTile(
            name: 'Somewhere',
            location: 'Palau, Micronesia',
            diveCount: 1,
            onTap: () {},
          ),
        ),
      );
      expect(find.byType(CountryFlag), findsNothing);
    });
  });
}
