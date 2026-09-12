import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/nav_track/presentation/widgets/nav_track_handoff_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Future<void> _pump(WidgetTester tester) async {
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: base,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NavTrackHandoffCard(
            bytes: Uint8List(0),
            fileName: '008.DAT.csv',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the recognised-format title, description and button', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Seacraft ENC navigation log recognised'), findsOneWidget);
    expect(
      find.textContaining('This is an underwater route, not a dive log.'),
      findsOneWidget,
    );
    expect(find.text('Review route'), findsOneWidget);
    expect(find.byIcon(Icons.route), findsOneWidget);
  });

  testWidgets('tapping the continue button pushes the review page', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Import Underwater Route'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('nav-track-handoff-continue')));
    await tester.pumpAndSettle();

    // The handoff card hands off to NavTrackImportReviewPage; its AppBar
    // title confirms the push actually happened rather than the button
    // being a no-op.
    expect(find.text('Import Underwater Route'), findsOneWidget);
  });
}
