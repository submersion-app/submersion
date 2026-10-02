import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/presentation/widgets/track_kind_badge.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('labels each kind', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Column(
          children: [
            TrackKindBadge(TrackKind.gps),
            TrackKindBadge(TrackKind.underwater),
          ],
        ),
      ),
    );
    expect(find.text('GPS'), findsOneWidget);
    expect(find.text('Underwater'), findsOneWidget);
    expect(find.byKey(const ValueKey('track-kind-badge-gps')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('track-kind-badge-underwater')),
      findsOneWidget,
    );
  });
}
