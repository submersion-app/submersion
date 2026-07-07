import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_recording_strip.dart';

import '../../helpers/test_app.dart';

const _recordingState = GpsRecorderState(
  status: GpsRecorderStatus.recording,
  trackId: 't1',
  pointCount: 2,
);

Widget app({List<dynamic>? overrides}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: GpsRecordingStrip()),
      ),
      GoRoute(
        path: '/gps-log',
        builder: (context, state) => const Scaffold(body: Text('GPS-LOG-PAGE')),
      ),
    ],
  );
  return testAppRouter(router: router, overrides: overrides);
}

void main() {
  testWidgets('renders nothing while idle', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('shows pluralized status while recording', (tester) async {
    await tester.pumpWidget(
      app(
        overrides: [
          gpsRecorderStateProvider.overrideWith(
            (ref) => Stream.value(_recordingState),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recording GPS track · 2 points'), findsOneWidget);
  });

  testWidgets('tap navigates to the GPS Log page', (tester) async {
    await tester.pumpWidget(
      app(
        overrides: [
          gpsRecorderStateProvider.overrideWith(
            (ref) => Stream.value(_recordingState),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(find.text('GPS-LOG-PAGE'), findsOneWidget);
  });
}
