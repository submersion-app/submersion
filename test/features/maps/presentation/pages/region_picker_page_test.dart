import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/maps/presentation/pages/region_picker_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('renders the RegionPickerPage FlutterMap', (tester) async {
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: base,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RegionPickerPage(),
        ),
      ),
    );

    // Avoid pumpAndSettle: the FlutterMap tile layer animates indefinitely.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(FlutterMap), findsWidgets);
  });
}
