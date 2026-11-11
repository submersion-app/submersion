import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_country.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_country_flags.dart';
import 'package:submersion/shared/widgets/country_flag.dart';

import '../../../../helpers/l10n_test_helpers.dart';

const _five = [
  TripCountry(code: 'MX', name: 'Mexico'),
  TripCountry(code: 'BZ', name: 'Belize'),
  TripCountry(code: 'HN', name: 'Honduras'),
  TripCountry(code: 'GT', name: 'Guatemala'),
  TripCountry(code: 'CR', name: 'Costa Rica'),
];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Map<String, List<TripCountry>> countries = const {'t1': _five},
  bool flags = true,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripCountriesProvider.overrideWith((ref) async => countries),
        showCountryFlagsProvider.overrideWithValue(flags),
      ],
      child: localizedMaterialApp(
        locale: locale,
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows at most maxFlags flags, then the rest as +N', (
    tester,
  ) async {
    await _pump(tester, const TripCountryFlags(tripId: 't1', maxFlags: 3));

    final codes = tester
        .widgetList<CountryFlag>(find.byType(CountryFlag))
        .map((f) => f.code)
        .toList();
    expect(codes, ['MX', 'BZ', 'HN']);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('without a limit shows every flag and no +N', (tester) async {
    await _pump(tester, const TripCountryFlags(tripId: 't1'));

    expect(find.byType(CountryFlag), findsNWidgets(5));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('exactly the limit shows no +N', (tester) async {
    await _pump(
      tester,
      const TripCountryFlags(tripId: 't1', maxFlags: 3),
      countries: {'t1': _five.take(3).toList()},
    );

    expect(find.byType(CountryFlag), findsNWidgets(3));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('flags off shows nothing', (tester) async {
    await _pump(tester, const TripCountryFlags(tripId: 't1'), flags: false);

    expect(find.byType(CountryFlag), findsNothing);
  });

  testWidgets('a trip with no countries shows nothing', (tester) async {
    await _pump(tester, const TripCountryFlags(tripId: 'other'));

    expect(find.byType(CountryFlag), findsNothing);
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('the group names every country for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const TripCountryFlags(tripId: 't1', maxFlags: 3));

    expect(
      find.bySemanticsLabel(
        'Countries: Mexico, Belize, Honduras, Guatemala, Costa Rica',
      ),
      findsOneWidget,
    );
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, 'Mexico, Belize, Honduras, Guatemala, Costa Rica');
    handle.dispose();
  });

  testWidgets('names are listed with the language own separator', (
    tester,
  ) async {
    await _pump(
      tester,
      const TripCountryFlags(tripId: 't1'),
      countries: {'t1': _five.take(2).toList()},
      locale: const Locale('zh'),
    );

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, 'Mexico、Belize');
  });

  testWidgets('the gap before the flags goes with them', (tester) async {
    await _pump(tester, const TripCountryFlags(tripId: 'other', gap: 6));
    expect(tester.getSize(find.byType(TripCountryFlags)), Size.zero);

    await _pump(tester, const TripCountryFlags(tripId: 't1', gap: 6));
    final group = tester.getTopLeft(find.byType(TripCountryFlags));
    final first = tester.getTopLeft(find.byType(CountryFlag).first);
    expect(first.dx - group.dx, 6);
  });
}
