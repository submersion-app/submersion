// A parse can outlive the wizard that started it. A large file parses on a
// worker, so the app stays responsive and the diver can close the wizard and
// start again before it finishes (#3865). What comes back then belongs to an
// import nobody is looking at, and must not land on the one they are.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/data/services/batch_parse_service.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

const _emptyUddf = '<uddf version="3.2.0"></uddf>';

const _oneDiveUddf = '''<uddf version="3.2.0">
  <profiledata>
    <repetitiongroup id="rg1">
      <dive id="d1">
        <informationbeforedive>
          <datetime>2026-02-20T14:00:00</datetime>
        </informationbeforedive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

PickedImportFile _file(Uint8List bytes) => PickedImportFile(
  name: 'export.uddf',
  bytes: bytes,
  detection: const DetectionResult(format: ImportFormat.uddf, confidence: 0.9),
  status: ImportFileStatus.pending,
);

Future<UniversalImportNotifier> _notifier({
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return container.read(universalImportNotifierProvider.notifier);
}

void _seed(UniversalImportNotifier notifier, List<Uint8List> files) {
  notifier.state = notifier.state.copyWith(
    detectionResult: const DetectionResult(
      format: ImportFormat.uddf,
      sourceApp: SourceApp.generic,
      confidence: 0.9,
    ),
    files: [for (final bytes in files) _file(bytes)],
  );
}

/// Holds a batch at its first file until [gate] opens, then reports what it
/// was told, the way the real service does between files.
class _GatedBatchParseService extends BatchParseService {
  _GatedBatchParseService(this.gate);

  final Completer<void> gate;
  bool? toldToStop;

  @override
  Future<BatchParseResult> parseAll(
    List<PickedImportFile> files, {
    void Function(int current, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    await gate.future;
    onProgress?.call(1, files.length);
    toldToStop = isCancelled?.call();
    return BatchParseResult(parsed: const [], files: files);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a single file', () {
    test('installs nothing once the wizard has dropped it', () async {
      final notifier = await _notifier();
      _seed(notifier, [_bytes(_oneDiveUddf)]);

      final parsing = notifier.confirmSource();
      notifier.reset();
      await parsing;

      expect(notifier.state.payload, isNull);
      expect(notifier.state.currentStep, ImportWizardStep.fileSelection);
    });

    test('leaves the file that replaced it alone', () async {
      final notifier = await _notifier();
      _seed(notifier, [_bytes(_oneDiveUddf)]);

      final parsing = notifier.confirmSource();
      _seed(notifier, [_bytes(_emptyUddf)]);
      await parsing;

      expect(notifier.state.payload, isNull);
      expect(notifier.state.error, isNull);
    });

    test('reports no failure once the wizard has dropped it', () async {
      final notifier = await _notifier();
      _seed(notifier, [_bytes(_emptyUddf)]);

      final parsing = notifier.confirmSource();
      notifier.reset();
      await parsing;

      expect(notifier.state.error, isNull);
    });

    test('reports no failure if dropped and then the parse throws', () async {
      // Reading the surfacing-pressure setting is part of producing the
      // payload, so a settings failure lands in the parse step's catch.
      final notifier = await _notifier(
        overrides: [
          settingsProvider.overrideWith((ref) => throw StateError('boom')),
        ],
      );
      _seed(notifier, [_bytes(_oneDiveUddf)]);

      final parsing = notifier.confirmSource();
      notifier.reset();
      await parsing;

      expect(notifier.state.error, isNull);
    });

    test('installs nothing if dropped during the duplicate check', () async {
      final gate = Completer<List<Trip>>();
      final notifier = await _notifier(
        overrides: [allTripsProvider.overrideWith((ref) => gate.future)],
      );
      _seed(notifier, [_bytes(_oneDiveUddf)]);

      final parsing = notifier.confirmSource();
      await pumpEventQueue();
      notifier.reset();
      gate.complete(const []);
      await parsing;

      expect(notifier.state.payload, isNull);
      expect(notifier.state.currentStep, ImportWizardStep.fileSelection);
    });
  });

  test(
    'a batch installs nothing if dropped during the duplicate check',
    () async {
      final gate = Completer<List<Trip>>();
      final notifier = await _notifier(
        overrides: [allTripsProvider.overrideWith((ref) => gate.future)],
      );
      _seed(notifier, [_bytes(_oneDiveUddf), _bytes(_oneDiveUddf)]);

      final parsing = notifier.confirmSource();
      await pumpEventQueue();
      notifier.reset();
      gate.complete(const []);
      await parsing;

      expect(notifier.state.payload, isNull);
      expect(notifier.state.files, isEmpty);
    },
  );

  test('a batch stops and writes nothing once the wizard drops it', () async {
    final service = _GatedBatchParseService(Completer<void>());
    final notifier = await _notifier(
      overrides: [
        universalImportNotifierProvider.overrideWith(
          (ref) => UniversalImportNotifier(ref, batchParseService: service),
        ),
      ],
    );
    _seed(notifier, [_bytes(_oneDiveUddf), _bytes(_oneDiveUddf)]);

    final parsing = notifier.confirmSource();
    notifier.reset();
    service.gate.complete();
    await parsing;

    expect(service.toldToStop, isTrue);
    expect(notifier.state.parseTotal, 0);
    expect(notifier.state.error, isNull);
    expect(notifier.state.files, isEmpty);
  });
}
