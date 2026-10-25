import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_empty_map.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/world_map_expectations.dart';

void main() {
  testWidgets('the empty Tracks map zooms and scrolls like the other maps '
      '(#3664)', (tester) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: base,
        child: const MaterialApp(
          home: Scaffold(body: GpsTrackEmptyMap(message: 'No tracks')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No tracks'), findsOneWidget);
    expectZoomsAndScrollsLikeOtherMaps(tester);
  });
}
