// A large file now parses on a worker, so the wizard stays live while it runs.
// That opens a window the old freeze kept shut: the diver can cancel, go back,
// leave or drop in another file with a parse still in flight. Each test here
// holds a parse open and acts in that window. Whatever happens, a parse that
// was given up on must never reach the state, because a late payload would
// land on a file it does not belong to.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/import_wizard/domain/models/import_step_failure.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/services/batch_parse_service.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

ImportPayload _payload(String name) => ImportPayload(
  entities: {
    ImportEntityType.dives: [
      {
        'dateTime': DateTime.utc(2024, 3, 10, 9),
        'maxDepth': 20.0,
        'notes': name,
      },
    ],
  },
);

String? _installedNotes(UniversalImportState state) =>
    state.payload?.entitiesOf(ImportEntityType.dives).single['notes']
        as String?;

/// Holds every parse open until the test finishes it, one call at a time.
class _HeldParser implements ImportParser {
  final _calls = <Completer<ImportPayload>>[];
  final _called = StreamController<void>.broadcast();

  /// Completes once the [n]th parse (counting from 1) has started.
  Future<void> reached(int n) async {
    while (_calls.length < n) {
      await _called.stream.first;
    }
  }

  void finish(int call, ImportPayload payload) =>
      _calls[call - 1].complete(payload);

  void fail(int call, Object error) => _calls[call - 1].completeError(error);

  @override
  List<ImportFormat> get supportedFormats => const [];

  @override
  Future<ImportPayload> parse(Uint8List fileBytes, {ImportOptions? options}) {
    final call = Completer<ImportPayload>();
    _calls.add(call);
    _called.add(null);
    return call.future;
  }
}

final _ssrf = Uint8List.fromList(
  utf8.encode("<divelog program='subsurface' version='3'><dives/></divelog>"),
);

PickedImportFile _pending(String name) => PickedImportFile(
  name: name,
  bytes: _ssrf,
  detection: const DetectionResult(
    format: ImportFormat.subsurfaceXml,
    sourceApp: SourceApp.subsurface,
    confidence: 1,
  ),
  status: ImportFileStatus.pending,
);

final _cancelled = throwsA(isA<ImportStepCancelled>());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  late _HeldParser parser;
  late UniversalImportNotifier notifier;

  /// [overrides] can hold a later stage of the pipeline open as well.
  Future<void> startWith({List<Override> overrides = const []}) async {
    parser = _HeldParser();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        universalImportNotifierProvider.overrideWith(
          (ref) => UniversalImportNotifier(
            ref,
            parserFor: (_) => parser,
            batchParseService: BatchParseService(parserFor: (_) => parser),
          ),
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    notifier = container.read(universalImportNotifierProvider.notifier);
  }

  group('a single file', () {
    setUp(() async {
      await startWith();
      await notifier.loadFileFromBytes(_ssrf, 'log.ssrf');
    });

    test('reads as loading while its parse runs', () async {
      unawaited(notifier.confirmSource().catchError((_) {}));
      await parser.reached(1);

      expect(notifier.state.isLoading, isTrue);

      notifier.cancelParse();
    });

    test('shows no file count left over from an earlier batch', () async {
      notifier.state = notifier.state.copyWith(parseCurrent: 2, parseTotal: 2);

      unawaited(notifier.confirmSource().catchError((_) {}));
      await parser.reached(1);

      expect(notifier.state.parseTotal, 0);
      expect(notifier.state.parseCurrent, 0);

      notifier.cancelParse();
    });

    test('cancelling returns to Confirm Source with no error', () async {
      final confirming = notifier.confirmSource();
      await parser.reached(1);

      notifier.cancelParse();

      await expectLater(confirming, _cancelled);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.payload, isNull);
      expect(notifier.state.error, isNull);
      expect(notifier.state.currentStep, ImportWizardStep.sourceConfirmation);
      expect(notifier.state.detectionResult, isNotNull);
    });

    test('a cancelled parse that finishes late changes nothing', () async {
      final confirming = notifier.confirmSource();
      await parser.reached(1);
      notifier.cancelParse();
      await expectLater(confirming, _cancelled);
      final settled = notifier.state;

      parser.finish(1, _payload('late'));
      await pumpEventQueue();

      expect(notifier.state, same(settled));
    });

    test('a cancelled parse that fails late reports nothing', () async {
      final confirming = notifier.confirmSource();
      await parser.reached(1);
      notifier.cancelParse();
      await expectLater(confirming, _cancelled);

      parser.fail(1, StateError('worker gave up'));
      await pumpEventQueue();

      expect(notifier.state.error, isNull);
    });

    test('can be confirmed again after a cancel', () async {
      final first = notifier.confirmSource();
      await parser.reached(1);
      notifier.cancelParse();
      await expectLater(first, _cancelled);

      final second = notifier.confirmSource();
      await parser.reached(2);
      parser.finish(2, _payload('second'));
      await second;

      expect(_installedNotes(notifier.state), 'second');
      expect(notifier.state.currentStep, ImportWizardStep.review);
    });

    test('a parse that fails before any cancel still reports it', () async {
      final confirming = notifier.confirmSource();
      await parser.reached(1);

      parser.fail(1, StateError('bad file'));

      await expectLater(confirming, throwsA(isA<ImportStepFailure>()));
      expect(notifier.state.error, contains('bad file'));
    });

    test('a reset drops the parse and keeps its clean slate', () async {
      final confirming = notifier.confirmSource();
      await parser.reached(1);

      notifier.reset();
      final fresh = notifier.state;

      await expectLater(confirming, _cancelled);
      parser.finish(1, _payload('late'));
      await pumpEventQueue();

      expect(notifier.state, same(fresh));
    });

    test('a new file replaces the parse in flight', () async {
      final oldFile = expectLater(notifier.confirmSource(), _cancelled);
      await parser.reached(1);

      await notifier.loadFileFromBytes(_ssrf, 'other.ssrf');
      await oldFile;

      final newFile = notifier.confirmSource();
      await parser.reached(2);
      parser.finish(2, _payload('new file'));
      await newFile;

      // The old file finishing last must not overwrite the one on screen.
      parser.finish(1, _payload('old file'));
      await pumpEventQueue();

      expect(_installedNotes(notifier.state), 'new file');
    });
  });

  test('cancelling during the duplicate check drops the payload', () async {
    // The check starts by reading the trips, so holding that read holds it.
    final trips = Completer<Never>();
    await startWith(
      overrides: [allTripsProvider.overrideWith((ref) => trips.future)],
    );
    await notifier.loadFileFromBytes(_ssrf, 'log.ssrf');
    final confirming = notifier.confirmSource();
    await parser.reached(1);
    parser.finish(1, _payload('parsed'));
    await pumpEventQueue();

    notifier.cancelParse();

    await expectLater(confirming, _cancelled);
    expect(notifier.state.payload, isNull);
    expect(notifier.state.isLoading, isFalse);
  });

  group('a batch', () {
    setUp(() async {
      await startWith();
      notifier.debugSetFilesForTest([_pending('a.ssrf'), _pending('b.ssrf')]);
    });

    test('cancelling during a file returns to triage at once', () async {
      final confirming = notifier.confirmSource();
      await parser.reached(1);

      notifier.cancelParse();

      await expectLater(confirming, _cancelled);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.parseTotal, 0);
      expect(notifier.state.payload, isNull);
      expect(notifier.state.currentStep, ImportWizardStep.sourceConfirmation);
      expect(notifier.state.files.map((f) => f.status), [
        ImportFileStatus.pending,
        ImportFileStatus.pending,
      ]);
    });

    test('files parsed before the cancel go back to pending', () async {
      final confirming = notifier.confirmSource();
      await parser.reached(1);
      parser.finish(1, _payload('a'));
      await parser.reached(2);

      notifier.cancelParse();

      await expectLater(confirming, _cancelled);
      expect(notifier.state.files.map((f) => f.status), [
        ImportFileStatus.pending,
        ImportFileStatus.pending,
      ]);
    });

    test('a reset during a file keeps its clean slate', () async {
      final confirming = notifier.confirmSource();
      await parser.reached(1);

      notifier.reset();
      final fresh = notifier.state;

      await expectLater(confirming, _cancelled);
      expect(notifier.state, same(fresh));
    });

    test('cancelling during the duplicate check returns to triage', () async {
      final trips = Completer<Never>();
      await startWith(
        overrides: [allTripsProvider.overrideWith((ref) => trips.future)],
      );
      notifier.debugSetFilesForTest([_pending('a.ssrf'), _pending('b.ssrf')]);
      final confirming = notifier.confirmSource();
      await parser.reached(1);
      parser.finish(1, _payload('a'));
      await parser.reached(2);
      parser.finish(2, _payload('b'));
      await pumpEventQueue();

      notifier.cancelParse();

      await expectLater(confirming, _cancelled);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.payload, isNull);
      expect(notifier.state.files.map((f) => f.status), [
        ImportFileStatus.pending,
        ImportFileStatus.pending,
      ]);
    });
  });
}
