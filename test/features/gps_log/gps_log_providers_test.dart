import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';

import '../../helpers/test_database.dart';

/// Exercises the provider factory bodies with the real graph (no overrides),
/// so the wiring that the widget/interaction tests stub out is still covered.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test('providers construct the real GPS collaborators', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(gpsTrackRepositoryProvider),
      isA<GpsTrackRepository>(),
    );
    expect(
      container.read(gpsTrackMatchServiceProvider),
      isA<GpsTrackMatchService>(),
    );
    expect(container.read(gpsTrackRecorderProvider), isA<GpsTrackRecorder>());
  });

  test('recorder is a keepalive singleton stopped on dispose', () async {
    final container = ProviderContainer();
    final recorder = container.read(gpsTrackRecorderProvider);
    expect(recorder.isRecording, isFalse);
    // onDispose(recorder.stop) must run without throwing on an idle recorder.
    container.dispose();
  });
}
