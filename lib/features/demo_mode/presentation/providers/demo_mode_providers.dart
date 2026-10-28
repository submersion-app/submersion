import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/core/services/security/database_security_service.dart';
import 'package:submersion/features/demo_mode/data/demo_database_preparer.dart';
import 'package:submersion/features/demo_mode/data/demo_database_switcher.dart';
import 'package:submersion/features/demo_mode/data/demo_downloader.dart';
import 'package:submersion/features/demo_mode/data/demo_manifest_client.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_service.dart';
import 'package:submersion/features/demo_mode/data/demo_package_extractor.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/data/demo_state_store.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart'
    show localThumbnailCacheProvider;
import 'package:submersion/features/settings/presentation/providers/nearby_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/main.dart' show restartApp;

final _log = LoggerService.forClass(DemoEnterController);

/// Whether the sample logbook is open. Read once per app scope: entering and
/// leaving demo mode restart the scope, so it never changes underneath it.
final demoModeActiveProvider = Provider<bool>(
  (ref) => DemoModeGate.instance.isActive,
);

final demoManifestClientProvider = Provider<DemoManifestClient>(
  (ref) => DemoManifestClient(),
);

/// The sample logbook this app can open, or null when none is reachable.
/// Fetched once per app session; both entry points stay hidden while null.
final demoAvailabilityProvider = FutureProvider<DemoPackage?>(
  (ref) => ref
      .watch(demoManifestClientProvider)
      .fetchBest(AppDatabase.currentSchemaVersion),
);

final demoModeServiceProvider = FutureProvider<DemoModeService>((ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final paths = await DemoPaths.resolve();
  return DemoModeService(
    paths: paths,
    prefs: prefs,
    store: DemoStateStore(paths),
    manifest: ref.read(demoManifestClientProvider),
    downloader: DemoDownloader(),
    extractor: DemoPackageExtractor(),
    preparer: DemoDatabasePreparer(),
    switcher: const DatabaseServiceDemoSwitcher(),
    realDatabasePath: () => DatabaseLocationService(prefs).getDatabasePath(),
    realKeyHex: () => DatabaseSecurityService.instance.databaseKeyHex,
    // A null origin reads as "imported here"; the sample photos are local.
    deviceId: () => null,
    cancelDeviceNotifications:
        NotificationService.instance.cancelAllNotifications,
    restart: restartApp,
    // With the gate closed, a refresh ends the running sessions (#3731).
    endNearbySync: () => ref.read(nearbyLinkManagerProvider).refresh(),
    forgetPhotos: (photoPaths) async {
      final thumbnails = ref.read(localThumbnailCacheProvider);
      for (final path in photoPaths) {
        await thumbnails.removePath(path);
      }
    },
  );
});

/// Leaves demo mode: restores the user's logbook and settings, removes every
/// demo file, and restarts the app.
final demoExitActionProvider = Provider<Future<void> Function()>(
  (ref) =>
      () async => (await ref.read(demoModeServiceProvider.future)).exit(),
);

/// Units and formats from the user's current settings, so the sample
/// logbook reads in units they already know.
DemoUnitSettings demoUnitsFromSettings(AppSettings s) => DemoUnitSettings({
  'depth_unit': s.depthUnit.name,
  'temperature_unit': s.temperatureUnit.name,
  'pressure_unit': s.pressureUnit.name,
  'volume_unit': s.volumeUnit.name,
  'weight_unit': s.weightUnit.name,
  'altitude_unit': s.altitudeUnit.name,
  'distance_unit': s.distanceUnit.name,
  'coordinate_format': s.coordinateFormat.name,
  'time_format': s.timeFormat.name,
  'date_format': s.dateFormat.name,
  'theme_mode': s.themeMode.name,
});

/// Units for a first-run user, from the preset their locale suggests.
DemoUnitSettings demoUnitsForPreset(UnitPreset preset) {
  final imperial = preset == UnitPreset.imperial;
  return DemoUnitSettings({
    'depth_unit': imperial ? 'feet' : 'meters',
    'temperature_unit': imperial ? 'fahrenheit' : 'celsius',
    'pressure_unit': imperial ? 'psi' : 'bar',
    'volume_unit': imperial ? 'cubicFeet' : 'liters',
    'weight_unit': imperial ? 'pounds' : 'kilograms',
    'altitude_unit': imperial ? 'feet' : 'meters',
    'distance_unit': imperial ? 'miles' : 'kilometers',
  });
}

sealed class DemoEnterUiState {
  const DemoEnterUiState();
}

class DemoEnterIdle extends DemoEnterUiState {
  const DemoEnterIdle();
}

class DemoEnterRunning extends DemoEnterUiState {
  const DemoEnterRunning(this.progress);

  final DemoEnterProgress progress;
}

/// The sample logbook on offer changed size since the user agreed to it, so
/// nothing was downloaded and they are asked again about [package].
class DemoEnterPackageChanged extends DemoEnterUiState {
  const DemoEnterPackageChanged(this.package);

  final DemoPackage package;
}

class DemoEnterFailed extends DemoEnterUiState {
  const DemoEnterFailed(this.reason);

  final DemoDownloadFailure reason;
}

/// Drives the "entering demo mode" dialog: progress, failure and retry.
class DemoEnterController extends Notifier<DemoEnterUiState> {
  /// Which entry is current. [cancel] and every [start] move it on, so a run
  /// that has been cancelled or superseded stops at its next chunk and no
  /// longer touches [state].
  int _run = 0;

  /// The entry in flight. A new one waits for it, since a cancelled run
  /// clears the demo directory on its way out.
  Future<void>? _inFlight;

  @override
  DemoEnterUiState build() => const DemoEnterIdle();

  /// Enters demo mode with [package], the one whose size the user agreed to.
  /// On success the app restarts into the sample logbook, so the last state
  /// seen here is [DemoEnterRunning].
  Future<void> start({
    required bool fromFirstRun,
    required DemoPackage package,
    DemoUnitSettings? units,
  }) {
    final run = ++_run;
    state = const DemoEnterRunning(
      DemoEnterProgress(DemoEnterStage.downloading),
    );
    final entry = (_inFlight ?? Future<void>.value()).then(
      (_) => _enter(
        run,
        fromFirstRun: fromFirstRun,
        package: package,
        units: units,
      ),
    );
    _inFlight = entry;
    return entry;
  }

  Future<void> _enter(
    int run, {
    required bool fromFirstRun,
    required DemoPackage package,
    DemoUnitSettings? units,
  }) async {
    bool current() => run == _run && ref.mounted;
    if (!current()) return;
    try {
      final service = await ref.read(demoModeServiceProvider.future);
      await service.enter(
        fromFirstRun: fromFirstRun,
        package: package,
        units: units,
        isCancelled: () => run != _run,
        onProgress: (p) {
          if (current()) state = DemoEnterRunning(p);
        },
      );
    } on DemoPackageChangedException catch (e) {
      // The entry points show the size from availability, so it is read
      // again for them too.
      ref.invalidate(demoAvailabilityProvider);
      if (current()) state = DemoEnterPackageChanged(e.current);
    } on DemoDownloadException catch (e) {
      if (current()) {
        state = e.reason == DemoDownloadFailure.cancelled
            ? const DemoEnterIdle()
            : DemoEnterFailed(e.reason);
      }
    } catch (e, st) {
      // Anything else, an Error included, still ends the dialog's spinner:
      // the opening stage has no button of its own.
      _log.error('Entering demo mode failed', error: e, stackTrace: st);
      if (current()) {
        state = const DemoEnterFailed(DemoDownloadFailure.network);
      }
    }
  }

  void cancel() => _run++;

  void reset() => state = const DemoEnterIdle();
}

final demoEnterControllerProvider =
    NotifierProvider<DemoEnterController, DemoEnterUiState>(
      DemoEnterController.new,
    );
