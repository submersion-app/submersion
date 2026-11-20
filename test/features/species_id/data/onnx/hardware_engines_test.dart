import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_vision/windows_ml.dart';

import 'package:submersion/features/species_id/data/engines/onnx/hardware_engines.dart';

/// A catalogue holding [engines]; preparing one makes it ready, unless its
/// name is in [refuse].
class FakeCatalogue implements WinMlCatalogue {
  FakeCatalogue(this._engines, {this.refuse = const {}, this.broken = false});

  List<WinMlEngine> _engines;
  final Set<String> refuse;
  final bool broken;
  final prepared = <String>[];

  @override
  Future<List<WinMlEngine>> engines() async {
    if (broken) throw StateError('Windows ML failed opening the catalogue');
    return _engines;
  }

  @override
  Future<bool> ensureReady(String name) async {
    prepared.add(name);
    if (refuse.contains(name)) throw StateError('download failed');
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

    test('an engine that is not ready is offered for fetching', () async {
      expect(
        await WindowsMlEngines(
          FakeCatalogue([_ready, _absent]),
        ).offersEngineToFetch(),
        isTrue,
      );
      expect(
        await WindowsMlEngines(FakeCatalogue([_ready])).offersEngineToFetch(),
        isFalse,
      );
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

  test('NoHardwareEngines offers and registers nothing', () async {
    const none = NoHardwareEngines();

    expect(await none.offersEngineToFetch(), isFalse);
    expect(await none.fetchEngine(), isFalse);
    expect(await none.readyProviderLibraries(), isEmpty);
  });
}
