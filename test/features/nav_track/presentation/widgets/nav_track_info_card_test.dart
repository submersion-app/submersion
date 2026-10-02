import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_info_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('shows the track and wires details and close', (tester) async {
    var opened = 0;
    var closed = 0;
    final route = NavTrack(
      id: 'r1',
      name: 'Wreck dive',
      source: NavTrackSource.seacraftEnc,
      startTime: 1755856800000,
      endTime: 1755860400000,
      durationSeconds: 600,
      pointCount: 5,
      totalDistance: 1050,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: base,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NavTrackInfoCard(
              route: route,
              onDetailsTap: () => opened++,
              onClose: () => closed++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wreck dive'), findsOneWidget);
    expect(find.textContaining('10min'), findsOneWidget);
    await tester.tap(find.byTooltip('View details'));
    await tester.tap(find.byIcon(Icons.close));
    expect(opened, 1);
    expect(closed, 1);
  });
}
