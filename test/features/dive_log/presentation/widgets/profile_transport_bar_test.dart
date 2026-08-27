import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_controls.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Dive _dive() => Dive(
  id: 'd1',
  dateTime: DateTime(2026, 1, 1, 10),
  profile: List.generate(
    61,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: 10, temperature: 20),
  ),
);

void main() {
  Widget wrap(Dive dive) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ProfileTransportBar(diveId: dive.id, profile: dive.profile),
      ),
    ),
  );

  testWidgets('renders the playback transport', (tester) async {
    await tester.pumpWidget(wrap(_dive()));
    await tester.pump();

    expect(find.byType(ProfileTransportControls), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('carries no metric tiles and no customize affordance', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_dive()));
    await tester.pump();

    expect(find.byIcon(Icons.tune), findsNothing);
    expect(find.text('Customize instruments'), findsNothing);
  });
}
