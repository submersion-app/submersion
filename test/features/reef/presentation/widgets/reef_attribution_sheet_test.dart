import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_attribution_sheet.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  testWidgets('names every data source the feature uses', (tester) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: const Scaffold(body: ReefAttributionSheet()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('NOAA Coral Reef Watch'), findsOneWidget);
    expect(find.textContaining('GBIF'), findsOneWidget);
    expect(find.textContaining('ProtectedSeas'), findsOneWidget);
    expect(find.textContaining('Reefs at Risk'), findsOneWidget);
  });

  testWidgets('states the licence for each attributed source', (tester) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: const Scaffold(body: ReefAttributionSheet()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('CC BY 4.0'), findsWidgets);
    expect(find.textContaining('CC BY 3.0'), findsWidgets);
  });
}
