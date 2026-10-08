import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);

void main() {
  group('siteGroupedSubtitle', () {
    test('joins locality and body of water', () {
      expect(
        siteGroupedSubtitle(
          const DiveSite(
            id: 'a',
            name: 'A',
            city: 'Dahab',
            bodyOfWater: 'Red Sea',
          ),
        ),
        'Dahab · Red Sea',
      );
    });

    test('falls back to the island and drops blanks', () {
      expect(
        siteGroupedSubtitle(
          const DiveSite(id: 'a', name: 'A', city: ' ', island: 'Bonaire'),
        ),
        'Bonaire',
      );
      expect(siteGroupedSubtitle(const DiveSite(id: 'a', name: 'A')), isNull);
    });
  });

  testWidgets('country header shows label, count and toggles', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        SiteCountryHeader(
          label: 'Australia',
          siteCount: 3,
          isExpanded: false,
          onTap: () => taps++,
        ),
      ),
    );
    expect(find.text('Australia'), findsOneWidget);
    expect(find.text('3 sites'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('Australia'));
    expect(taps, 1);
  });

  testWidgets('an expanded header shows the open chevron', (tester) async {
    await tester.pumpWidget(
      _host(
        SiteCountryHeader(
          label: 'Fiji',
          siteCount: 1,
          isExpanded: true,
          onTap: () {},
        ),
      ),
    );
    expect(find.text('1 site'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('the no-country group gets its localized label', (tester) async {
    late String label;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            final group = groupSitesByLocation(const [
              DiveSite(id: 'a', name: 'A'),
            ], (s) => s).single;
            label = countryGroupLabel(AppLocalizations.of(context), group);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(label, 'No country');
  });
}
