import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';

/// buildSettings is pure (no DB, no stream), so these run without the
/// database/controller fixture the lifecycle tests need.
void main() {
  final recorder = GpsTrackRecorder(repository: GpsTrackRepository());

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('android uses a foreground-service notification config', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final settings = recorder.buildSettings('Title', 'Text');
    expect(settings, isA<AndroidSettings>());
    final android = settings as AndroidSettings;
    expect(android.foregroundNotificationConfig, isNotNull);
    expect(android.foregroundNotificationConfig!.notificationTitle, 'Title');
    expect(android.foregroundNotificationConfig!.notificationText, 'Text');
    expect(android.foregroundNotificationConfig!.enableWakeLock, isTrue);
    expect(android.distanceFilter, GpsTrackRecorder.distanceFilterMeters);
  });

  test('iOS enables background location updates', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final settings = recorder.buildSettings('Title', 'Text');
    expect(settings, isA<AppleSettings>());
    final apple = settings as AppleSettings;
    expect(apple.allowBackgroundLocationUpdates, isTrue);
    expect(apple.showBackgroundLocationIndicator, isTrue);
    expect(apple.pauseLocationUpdatesAutomatically, isFalse);
  });

  test('macOS also uses Apple settings', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(recorder.buildSettings('t', 'x'), isA<AppleSettings>());
  });

  test('desktop platforms get plain settings', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final settings = recorder.buildSettings('Title', 'Text');
    expect(settings, isNot(isA<AndroidSettings>()));
    expect(settings, isNot(isA<AppleSettings>()));
    expect(settings.distanceFilter, GpsTrackRecorder.distanceFilterMeters);
  });
}
