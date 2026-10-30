import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/sync_device_footprint.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_library_probe.dart';
import 'package:submersion/features/settings/presentation/providers/sync_device_providers.dart';

final _published = DateTime(2026, 10, 20, 9, 30);

SyncDeviceFootprint _footprint(
  String id,
  SyncDeviceFootprintState state, {
  String? name,
  bool isSelf = false,
  DateTime? publishedAt,
}) => SyncDeviceFootprint(
  deviceId: id,
  state: state,
  fileCount: 3,
  byteCount: 1024,
  deviceName: name,
  isSelf: isSelf,
  publishedAt: publishedAt,
);

const _marker = LibraryEpochMarker(
  epochId: 'epoch-2',
  replacedAt: 1700000000000,
  deviceId: 'peer-1',
  deviceName: "Eric's iPhone",
);

/// Step 2's reading of the account (issue #3482, Part B Task 9): the
/// combination of what the account holds, from inputs the sync engine's
/// own tests cover.
void main() {
  Future<SetUpLibrary> probe({
    int localDives = 0,
    PeerLibraryState peers = PeerLibraryState.pullable,
    LibraryEpochMarker? marker,
    List<SyncDeviceFootprint> footprints = const [],
    bool accountFails = false,
  }) {
    final c = ProviderContainer(
      overrides: [
        setUpLocalDiveCountProvider.overrideWith((ref) async => localDives),
        setUpPeerLibraryStateProvider.overrideWith(
          (ref) async => accountFails ? throw StateError('unreachable') : peers,
        ),
        setUpReplaceMarkerProvider.overrideWith((ref) async => marker),
        syncDeviceFootprintListProvider.overrideWith((ref) async => footprints),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(setUpLibraryProvider, (_, _) {});
    addTearDown(sub.close);
    return c.read(setUpLibraryProvider.future);
  }

  test('no library: the dives here become the library', () async {
    final result = await probe(localDives: 5, peers: PeerLibraryState.none);
    expect(result, isA<NoLibrary>());
    expect((result as NoLibrary).localDives, 5);
  });

  test('a library names the device that last changed it, and when', () async {
    final result = await probe(
      localDives: 2,
      footprints: [
        _footprint('self', SyncDeviceFootprintState.active, isSelf: true),
        _footprint(
          'peer-old',
          SyncDeviceFootprintState.active,
          name: 'Old iPad',
          publishedAt: DateTime(2026, 9, 1),
        ),
        _footprint(
          'peer-1',
          SyncDeviceFootprintState.active,
          name: "Eric's iPhone",
          publishedAt: _published,
        ),
        _footprint('peer-gone', SyncDeviceFootprintState.retired),
      ],
    );

    expect(result, isA<LibraryFound>());
    final found = result as LibraryFound;
    expect(found.deviceName, "Eric's iPhone");
    expect(found.changedAt, _published);
    expect(found.localDives, 2);
  });

  test('a library no peer manifest of can be read is locked', () async {
    final result = await probe(
      footprints: [
        _footprint('self', SyncDeviceFootprintState.active, isSelf: true),
        _footprint('peer-1', SyncDeviceFootprintState.unreadable),
      ],
    );
    expect(result, isA<LibraryLocked>());
  });

  test('an upload left unfinished is incomplete', () async {
    final result = await probe(peers: PeerLibraryState.incomplete);
    expect(result, isA<LibraryIncomplete>());
  });

  test('a replaced library awaits adoption on a device with dives', () async {
    final result = await probe(localDives: 3, marker: _marker);
    expect(result, isA<LibraryAwaitingAdoption>());
    expect((result as LibraryAwaitingAdoption).marker.epochId, 'epoch-2');
  });

  // The first sync adopts a replaced library silently where there is
  // nothing to set aside.
  test(
    'a replaced library is simply downloaded onto an empty device',
    () async {
      final result = await probe(marker: _marker);
      expect(result, isA<LibraryFound>());
    },
  );

  test('an account that cannot be read says so', () async {
    final result = await probe(accountFails: true);
    expect(result, isA<LibraryUnreachable>());
  });

  test('the dive count is not awaited for nothing when the account fails', () {
    // Guards the provider against waiting on a count that never comes.
    final c = ProviderContainer(
      overrides: [
        setUpLocalDiveCountProvider.overrideWith(
          (ref) => Completer<int>().future,
        ),
        setUpPeerLibraryStateProvider.overrideWith(
          (ref) async => throw StateError('unreachable'),
        ),
        setUpReplaceMarkerProvider.overrideWith((ref) async => null),
        syncDeviceFootprintListProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(setUpLibraryProvider, (_, _) {});
    addTearDown(sub.close);
    expect(
      c.read(setUpLibraryProvider.future),
      completion(isA<LibraryUnreachable>()),
    );
  });
}
