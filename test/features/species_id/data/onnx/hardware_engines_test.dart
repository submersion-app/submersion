import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_vision/windows_ml.dart';

import 'package:submersion/features/species_id/data/engines/onnx/hardware_engines.dart';

/// A catalogue holding [engines]; preparing one makes it ready, unless its
/// name is in [refuse].
class FakeCatalogue implements WinMlCatalogue {
  FakeCatalogue(
    this._engines, {
    this.refuse = const {},
    this.hang = const {},
    this.broken = false,
    this.readsBeforeBreaking,
  });

  List<WinMlEngine> _engines;
  final Set<String> refuse;

  /// Engines whose preparing never finishes (a stalled download).
  final Set<String> hang;
  final bool broken;

  /// Reads that work before every later one fails.
  int? readsBeforeBreaking;
  final prepared = <String>[];

  @override
  Future<List<WinMlEngine>> engines() async {
    if (broken) throw StateError('Windows ML failed opening the catalogue');
    final left = readsBeforeBreaking;
    if (left != null) {
      if (left == 0) throw StateError('Windows ML failed listing engines');
      readsBeforeBreaking = left - 1;
    }
    return _engines;
  }

  @override
  Future<bool> ensureReady(String name) async {
    prepared.add(name);
    if (refuse.contains(name)) throw StateError('download failed');
    if (hang.contains(name)) return Completer<bool>().future;
    _engines = [
      for (final e in _engines)
        e.name == name
            ? WinMlEngine(
                name: name,
                state: WinMlReadyState.ready,
                libraryPath: 'C:\\engines\\$name.dll',
              )
            : e,
    ];
    return true;
  }
}

const _ready = WinMlEngine(
  name: 'NvTensorRTRTXExecutionProvider',
  state: WinMlReadyState.ready,
  libraryPath: 'C:\\engines\\nv.dll',
);
const _installed = WinMlEngine(
  name: 'QNNExecutionProvider',
  state: WinMlReadyState.notReady,
  libraryPath: '',
);
const _absent = WinMlEngine(
  name: 'OpenVINOExecutionProvider',
  state: WinMlReadyState.notPresent,
  libraryPath: '',
);

void main() {
  group('WindowsMlEngines', () {
    test('only a ready engine has its library registered', () async {
      final engines = WindowsMlEngines(FakeCatalogue([_ready, _absent]));

      expect(await engines.readyProviderLibraries(), [
        (name: 'NvTensorRTRTXExecutionProvider', path: 'C:\\engines\\nv.dll'),
      ]);
    });

    test('an engine that is installed but not ready is prepared and '
        'registered when the worker starts, with nothing to fetch', () async {
      // Windows ML adds an installed engine to each process anew, so it
      // reads as not ready after every launch.
      final catalogue = FakeCatalogue([_installed]);
      final engines = WindowsMlEngines(catalogue);

      expect(await engines.readyProviderLibraries(), [
        (
          name: 'QNNExecutionProvider',
          path: 'C:\\engines\\QNNExecutionProvider.dll',
        ),
      ]);
      expect(catalogue.prepared, ['QNNExecutionProvider']);
      expect(await engines.offersEngineToFetch(), isFalse);
    });

    test(
      'only an engine that is not on this PC is offered for fetching',
      () async {
        expect(
          await WindowsMlEngines(
            FakeCatalogue([_ready, _absent]),
          ).offersEngineToFetch(),
          isTrue,
        );
        expect(
          await WindowsMlEngines(
            FakeCatalogue([_ready, _installed]),
          ).offersEngineToFetch(),
          isFalse,
        );
      },
    );

    test(
      'a download that never finishes gives up, so the install goes on',
      () async {
        final catalogue = FakeCatalogue(
          [_absent],
          hang: {'OpenVINOExecutionProvider'},
        );
        final engines = WindowsMlEngines(
          catalogue,
          fetchTimeout: const Duration(milliseconds: 20),
        );

        expect(await engines.fetchEngine(), isFalse);
      },
    );

    test('an installed engine that never gets ready is left out', () async {
      final engines = WindowsMlEngines(
        FakeCatalogue([_ready, _installed], hang: {'QNNExecutionProvider'}),
        prepareTimeout: const Duration(milliseconds: 20),
      );

      expect(await engines.readyProviderLibraries(), [
        (name: 'NvTensorRTRTXExecutionProvider', path: 'C:\\engines\\nv.dll'),
      ]);
    });

    test('fetching prepares each engine that is not ready', () async {
      final catalogue = FakeCatalogue([_ready, _absent]);
      final engines = WindowsMlEngines(catalogue);

      expect(await engines.fetchEngine(), isTrue);
      expect(catalogue.prepared, ['OpenVINOExecutionProvider']);
      expect(await engines.readyProviderLibraries(), hasLength(2));
    });

    test(
      'an engine that fails to arrive fails the fetch, not the caller',
      () async {
        final catalogue = FakeCatalogue(
          [_absent],
          refuse: {'OpenVINOExecutionProvider'},
        );

        expect(await WindowsMlEngines(catalogue).fetchEngine(), isFalse);
      },
    );

    test('a catalogue that cannot be read offers nothing and registers '
        'nothing', () async {
      final engines = WindowsMlEngines(FakeCatalogue([], broken: true));

      expect(await engines.offersEngineToFetch(), isFalse);
      expect(await engines.fetchEngine(), isFalse);
      expect(await engines.readyProviderLibraries(), isEmpty);
    });
  });

  test('one deadline covers the whole fetch, not each engine', () async {
    final catalogue = FakeCatalogue(
      [
        _absent,
        const WinMlEngine(
          name: 'MIGraphXExecutionProvider',
          state: WinMlReadyState.notPresent,
          libraryPath: '',
        ),
      ],
      hang: {'OpenVINOExecutionProvider', 'MIGraphXExecutionProvider'},
    );
    final engines = WindowsMlEngines(
      catalogue,
      fetchTimeout: const Duration(milliseconds: 30),
    );

    expect(await engines.fetchEngine(), isFalse);
    expect(catalogue.prepared, ['OpenVINOExecutionProvider']);
  });

  test(
    'a failed second read keeps the engines that were already ready',
    () async {
      final engines = WindowsMlEngines(
        FakeCatalogue([_ready, _installed], readsBeforeBreaking: 1),
      );

      expect(await engines.readyProviderLibraries(), [
        (name: 'NvTensorRTRTXExecutionProvider', path: 'C:\\engines\\nv.dll'),
      ]);
    },
  );

  test('NoHardwareEngines offers and registers nothing', () async {
    const none = NoHardwareEngines();

    expect(await none.offersEngineToFetch(), isFalse);
    expect(await none.fetchEngine(), isFalse);
    expect(await none.readyProviderLibraries(), isEmpty);
  });
}
