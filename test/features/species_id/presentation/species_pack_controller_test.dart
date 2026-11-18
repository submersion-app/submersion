import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_downloader.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_pack_controller.dart';

import '../../../helpers/temp_dir.dart';
import '../data/fake_vision_engine.dart';
import '../domain/manifest_fixture.dart';
import 'species_id_fakes.dart';

class _Client extends SpeciesPackManifestClient {
  _Client() : super(url: Uri.parse('https://example.test/pack/manifest.json'));

  SpeciesPackManifest? manifest;
  Object? failure;

  @override
  Future<SpeciesPackManifest?> fetch() async {
    if (failure != null) throw failure!;
    return manifest;
  }
}

class _Downloader extends SpeciesPackDownloader {
  Object? failure;
  Completer<void>? gate;
  var calls = 0;
  final downloaded = <String>[];

  @override
  Future<void> downloadFile({
    required Uri url,
    required PackFile file,
    required File dest,
    void Function(int receivedForThisFile)? onProgress,
    bool Function()? isCancelled,
  }) async {
    calls++;
    if (isCancelled?.call() ?? false) {
      throw const PackDownloadException(PackDownloadFailure.cancelled);
    }
    await gate?.future;
    onProgress?.call(file.size ~/ 2);
    if (failure != null) throw failure!;
    await dest.writeAsString('x');
    downloaded.add(file.name);
    onProgress?.call(file.size);
  }
}

class _Store extends SpeciesPackStore {
  _Store(String root) : super(supportPath: () async => root, engine: 'coreml');

  InstalledPack? current;
  var installs = 0;
  var removals = 0;

  /// Whether the pack is being changed with analysis held, read at each
  /// install and removal.
  bool Function() changing = () => false;
  final heldAtInstall = <bool>[];
  final heldAtRemoval = <bool>[];

  @override
  Future<InstalledPack?> installed() async => current;

  @override
  Future<InstalledPack> install(SpeciesPackManifest manifest) async {
    installs++;
    heldAtInstall.add(changing());
    return current = InstalledPack(
      manifest: manifest,
      directory: '/pack',
      detectorPaths: const ['/pack/d'],
      classifierPath: '/pack/c',
    );
  }

  @override
  Future<void> remove() async {
    removals++;
    heldAtRemoval.add(changing());
    current = null;
  }

  @override
  Future<int> sizeBytes() async => current == null ? 0 : 123;
}

class _Service extends RecordingIdentificationService {
  var packChanges = 0;
  var changing = false;

  @override
  Future<T> changePack<T>(Future<T> Function() change) async {
    packChanges++;
    changing = true;
    try {
      return await change();
    } finally {
      changing = false;
    }
  }
}

SpeciesPackManifest _manifest({String version = '2026.11.1'}) =>
    SpeciesPackManifest.parse(manifestJson((m) => m['packVersion'] = version));

void main() {
  late Directory root;
  late FakeEngine engine;
  late _Client client;
  late _Downloader downloader;
  late _Store store;
  late _Service service;
  late ProviderContainer container;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pack_controller');
    engine = FakeEngine();
    client = _Client()..manifest = _manifest();
    downloader = _Downloader();
    store = _Store(root.path);
    service = _Service();
    store.changing = () => service.changing;
    container = ProviderContainer(
      overrides: [
        visionEngineProvider.overrideWithValue(engine),
        speciesPackManifestClientProvider.overrideWithValue(client),
        speciesPackDownloaderProvider.overrideWithValue(downloader),
        speciesPackStoreProvider.overrideWithValue(store),
        mediaIdentificationServiceProvider.overrideWithValue(service),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await deleteTempDir(root);
  });

  SpeciesPackController controller() =>
      container.read(speciesPackControllerProvider.notifier);
  SpeciesPackState state() => container.read(speciesPackControllerProvider);

  test('a device that cannot run the models says why', () async {
    engine.available = VisionAvailability.deviceNotEligible;
    await controller().refresh();
    expect(
      state(),
      isA<PackUnsupported>().having(
        (s) => s.reason,
        'reason',
        VisionAvailability.deviceNotEligible,
      ),
    );
  });

  test('nothing published', () async {
    client.manifest = null;
    await controller().refresh();
    expect(state(), isA<PackNotPublished>());
  });

  test('a pack with no models for this engine', () async {
    client.manifest = SpeciesPackManifest.parse(
      manifestJson((m) {
        final files = (m['files']! as List).cast<Map<String, Object?>>();
        for (final f in files) {
          if (f['engine'] == 'coreml') f['engine'] = 'onnx';
        }
      }),
    );
    await controller().refresh();
    expect(state(), isA<PackNotForThisDevice>());
  });

  test('a newer format asks for an app update', () async {
    client.failure = const PackDownloadException(
      PackDownloadFailure.unsupportedFormat,
    );
    await controller().refresh();
    expect(state(), isA<PackNeedsAppUpdate>());
  });

  test(
    'an unexpected error while checking ends as failed, not checking',
    () async {
      client.failure = StateError('broken');
      await controller().refresh();
      expect(state(), isA<PackFailed>());
    },
  );

  test('a published pack not yet downloaded quotes its size', () async {
    await controller().refresh();
    final s = state() as PackNotInstalled;
    expect(s.bytes, _manifest().downloadBytesFor('coreml'));
    expect(s.resumable, isFalse);
  });

  test('downloading reports progress and ends installed', () async {
    await controller().refresh();
    final seen = <SpeciesPackState>[];
    final sub = container.listen(
      speciesPackControllerProvider,
      (_, next) => seen.add(next),
    );
    addTearDown(sub.close);
    await controller().download();

    expect(seen.whereType<PackDownloading>(), isNotEmpty);
    final last = seen.whereType<PackDownloading>().last;
    expect(last.received, last.total);
    expect(state(), isA<PackInstalled>());
    expect((state() as PackInstalled).version, '2026.11.1');
    expect(downloader.downloaded, hasLength(5));
    expect(store.installs, 1);
    expect(service.packChanges, 1);
  });

  test('a failed download can be continued', () async {
    await controller().refresh();
    downloader.failure = const PackDownloadException(
      PackDownloadFailure.network,
    );
    await controller().download();
    expect(
      state(),
      isA<PackFailed>().having(
        (s) => s.reason,
        'reason',
        PackDownloadFailure.network,
      ),
    );
    // The first file's part is left in staging.
    final staging = await store.staging('2026.11.1');
    await File(
      p.join(staging.path, 'detector.coreml.zip.part'),
    ).writeAsString('x');
    await controller().refresh();
    expect((state() as PackNotInstalled).resumable, isTrue);
  });

  test('a full disk is its own failure', () async {
    await controller().refresh();
    downloader.failure = const PackDownloadException(
      PackDownloadFailure.storage,
    );
    await controller().download();
    expect((state() as PackFailed).reason, PackDownloadFailure.storage);
  });

  test('cancelling stops the download', () async {
    await controller().refresh();
    controller().cancel();
    await controller().download();
    // A cancel before the start is dropped: a new download begins fresh.
    expect(state(), isA<PackInstalled>());

    store.current = null;
    await controller().refresh();
    downloader.failure = null;
    final pending = controller().download();
    controller().cancel();
    await pending;
    // Cancelling is not a failure: the page offers the download again.
    expect(state(), isA<PackNotInstalled>());
  });

  test('installing prepares the models once, as part of it', () async {
    await controller().refresh();
    final seen = <SpeciesPackState>[];
    final sub = container.listen(
      speciesPackControllerProvider,
      (_, next) => seen.add(next),
    );
    addTearDown(sub.close);
    await controller().download();
    expect(seen.whereType<PackInstalling>(), isNotEmpty);
    expect(engine.loads.single.detectors.single.path, '/pack/d');
    expect(engine.unloads, 1);
    expect(state(), isA<PackInstalled>());
  });

  test('a pack whose models do not load is not left installed', () async {
    await controller().refresh();
    engine.loadFailure = Exception('not a model');
    await controller().download();
    expect(state(), isA<PackFailed>());
    expect(store.removals, 1);
    expect(store.current, isNull);
  });

  test(
    'coming back to the page during a download does not disturb it',
    () async {
      await controller().refresh();
      downloader.gate = Completer<void>();
      final pending = controller().download();
      await pumpEventQueue();
      await controller().refresh();
      expect(state(), isA<PackDownloading>());
      final again = controller().download();
      downloader.gate!.complete();
      await Future.wait([pending, again]);
      expect(downloader.calls, 5);
      expect(store.installs, 1);
      expect(state(), isA<PackInstalled>());
    },
  );

  test('an unexpected failure ends the download as failed', () async {
    await controller().refresh();
    downloader.failure = StateError('broken');
    await controller().download();
    expect(state(), isA<PackFailed>());
  });

  test(
    'installed shows the version and an update when one is published',
    () async {
      await controller().refresh();
      await controller().download();
      client.manifest = _manifest(version: '2026.12.1');
      await controller().refresh();
      final s = state() as PackInstalled;
      expect(s.version, '2026.11.1');
      expect(s.updateBytes, _manifest().downloadBytesFor('coreml'));
    },
  );

  test('the pack is installed and removed with analysis held', () async {
    await controller().refresh();
    await controller().download();
    await controller().remove();
    expect(store.heldAtInstall, [true]);
    expect(store.heldAtRemoval, [true]);
  });

  test('removing goes back to not installed', () async {
    await controller().refresh();
    await controller().download();
    await controller().remove();
    expect(store.removals, 1);
    expect(state(), isA<PackNotInstalled>());
    expect(service.packChanges, 2);
  });

  test('offline with a pack installed still shows it', () async {
    await controller().refresh();
    await controller().download();
    client.failure = const PackDownloadException(PackDownloadFailure.network);
    await controller().refresh();
    expect(state(), isA<PackInstalled>());
  });
}
