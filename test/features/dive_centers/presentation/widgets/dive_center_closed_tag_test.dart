import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_closed_tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('reads Closed and is not a Chip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: DiveCenterClosedTag())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Closed'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);
  });

  test('every closed surface greys to the same opacity', () {
    expect(kClosedDiveCenterOpacity, 0.6);
  });
}
