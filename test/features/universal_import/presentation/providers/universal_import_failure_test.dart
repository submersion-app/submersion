// A failed acquisition step must stop the wizard where it is, not let it
// advance onto a step that has nothing to act on.
//
// Reported on ScubaBoard against v1.7.6: a UDDF/SSRF/XML import "is detected"
// and then parks on the CSV-only Map Fields step reading "0 of 0 columns
// mapped" with Next dead and no message anywhere. The parse (or the database
// read the duplicate check does) had failed, leaving payload null, and every
// gate the wizard gates on is spelled in terms of that payload.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/import_wizard/domain/models/import_step_failure.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

final _en = lookupAppLocalizations(const Locale('en'));
final _de = lookupAppLocalizations(const Locale('de'));

const _emptyUddf = '<uddf version="3.2.0"></uddf>';

const _oneDiveUddf = '''<uddf version="3.2.0">
  <profiledata>
    <repetitiongroup id="rg1">
      <dive id="d1">
        <informationbeforedive>
          <datetime>2026-02-20T14:00:00</datetime>
          <divenumber>2</divenumber>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>22.0</greatestdepth>
          <diveduration>1800.0</diveduration>
        </informationafterdive>
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

/// [locale] is the language setting (`en`, `de`, ...); left null, the
/// notifier follows the test platform, which is English.
Future<UniversalImportNotifier> _notifier({
  String? locale,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (locale != null) localeProvider.overrideWithValue(locale),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return container.read(universalImportNotifierProvider.notifier);
}

void _seed(UniversalImportNotifier notifier, Uint8List bytes) {
  notifier.state = notifier.state.copyWith(
    detectionResult: const DetectionResult(
      format: ImportFormat.uddf,
      sourceApp: SourceApp.generic,
      confidence: 0.9,
    ),
    files: [_file(bytes)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a non-CSV import that produces nothing', () {
    setUp(setUpTestDatabase);
    tearDown(tearDownTestDatabase);

    test(
      'reports the failure instead of advancing with a null payload',
      () async {
        final notifier = await _notifier();
        _seed(notifier, _bytes(_emptyUddf));

        await expectLater(
          notifier.confirmSource(),
          throwsA(isA<ImportStepFailure>()),
        );
        expect(notifier.state.payload, isNull);
        expect(notifier.state.error, isNotNull);
        expect(notifier.state.isLoading, isFalse);
      },
    );

    test('drops the payload a previous attempt left behind', () async {
      // Reachable by backtracking: parse a file, walk back to Confirm Source,
      // change the source and confirm again. The second parse fails, but the
      // first one's payload is still in state -- and every gate past this
      // point reads that payload, so the wizard would carry a superseded
      // import forward under a message saying the current one failed.
      final notifier = await _notifier();
      _seed(notifier, _bytes(_oneDiveUddf));
      await notifier.confirmSource();
      expect(notifier.state.payload, isNotNull, reason: 'first parse');

      _seed(notifier, _bytes(_emptyUddf));
      await expectLater(
        notifier.confirmSource(),
        throwsA(isA<ImportStepFailure>()),
      );

      expect(notifier.state.payload, isNull);
      expect(notifier.state.duplicateResult, isNull);
      expect(notifier.state.selections, isEmpty);
      expect(notifier.state.error, isNotNull);
    });

    test('drops the payload when the source is re-confirmed as CSV', () async {
      // The CSV branch of confirmSource hands off to Map Fields instead of
      // parsing, so it never reaches _fail. Without clearing, overriding the
      // source to CSV after a successful parse leaves the old payload in
      // place: Map Fields auto-skips on it, confirmFieldMapping early-returns
      // on it, and Review shows the superseded import.
      final notifier = await _notifier();
      _seed(notifier, _bytes(_oneDiveUddf));
      await notifier.confirmSource();
      expect(notifier.state.payload, isNotNull, reason: 'first parse');

      await notifier.confirmSource(
        overrideApp: SourceApp.generic,
        overrideFormat: ImportFormat.csv,
      );

      expect(notifier.state.payload, isNull);
      expect(notifier.state.currentStep, ImportWizardStep.fieldMapping);
    });

    test('carries the parser\'s own complaint through verbatim', () async {
      // Every parser in the registry handles its own errors and returns an
      // empty payload carrying a warning, rather than throwing (checked
      // against shearwaterDb, macdiveSqlite, fit and danDl7 on garbage bytes
      // as well as this one). So the message the user ends up reading is the
      // parser's, and it must not be flattened into a generic one on the way
      // out: "Expected a single root element at 1:25" tells them their file
      // is truncated, where "could not be imported" tells them nothing.
      final notifier = await _notifier();
      notifier.state = notifier.state.copyWith(
        detectionResult: const DetectionResult(
          format: ImportFormat.subsurfaceXml,
          sourceApp: SourceApp.subsurface,
          confidence: 0.9,
        ),
        files: [_file(_bytes('not valid xml at all {{{'))],
      );

      await expectLater(
        notifier.confirmSource(
          overrideApp: SourceApp.subsurface,
          overrideFormat: ImportFormat.subsurfaceXml,
        ),
        throwsA(
          isA<ImportStepFailure>().having(
            (e) => e.message,
            'message',
            contains('Failed to parse XML'),
          ),
        ),
      );
      expect(notifier.state.error, contains('Failed to parse XML'));
      expect(notifier.state.payload, isNull);
      expect(notifier.state.isLoading, isFalse);
    });

    test('leads the parser\'s complaint with the diver\'s language', () async {
      // The parser's text is kept for what it says about the file, but the
      // sentence around it follows the language setting.
      final notifier = await _notifier(locale: 'de');
      notifier.state = notifier.state.copyWith(
        detectionResult: const DetectionResult(
          format: ImportFormat.subsurfaceXml,
          sourceApp: SourceApp.subsurface,
          confidence: 0.9,
        ),
        files: [_file(_bytes('not valid xml at all {{{'))],
      );

      await expectLater(
        notifier.confirmSource(
          overrideApp: SourceApp.subsurface,
          overrideFormat: ImportFormat.subsurfaceXml,
        ),
        throwsA(isA<ImportStepFailure>()),
      );
      expect(
        notifier.state.error,
        startsWith(_de.universalImport_error_noDataInFileWithDetails('')),
      );
      expect(notifier.state.error, contains('Failed to parse XML'));
    });

    test('reports a parse that throws, in the diver\'s language', () async {
      // Reading the surfacing-pressure setting is part of producing the
      // payload, so a settings failure lands in the parse step's catch.
      final notifier = await _notifier(
        locale: 'de',
        overrides: [
          settingsProvider.overrideWith((ref) => throw StateError('boom')),
        ],
      );
      _seed(notifier, _bytes(_oneDiveUddf));

      // Riverpod wraps the provider's own error, so the cause is contained in
      // the details rather than being all of them.
      await expectLater(
        notifier.confirmSource(),
        throwsA(
          isA<ImportStepFailure>().having(
            (e) => e.message,
            'message',
            allOf(
              startsWith(_de.universalImport_error_parseFailed('')),
              contains('Bad state: boom'),
            ),
          ),
        ),
      );
    });

    test('reports the failure when the picked file carries no bytes', () async {
      final notifier = await _notifier();
      notifier.state = notifier.state.copyWith(
        detectionResult: const DetectionResult(
          format: ImportFormat.uddf,
          sourceApp: SourceApp.generic,
          confidence: 0.9,
        ),
        files: [
          const PickedImportFile(
            name: 'export.uddf',
            path: '/nowhere/export.uddf',
            detection: DetectionResult(
              format: ImportFormat.uddf,
              confidence: 0.9,
            ),
            status: ImportFileStatus.pending,
          ),
        ],
      );

      await expectLater(
        notifier.confirmSource(),
        throwsA(isA<ImportStepFailure>()),
      );
      expect(notifier.state.error, _en.universalImport_error_fileUnreadable);
    });
  });

  group('a CSV whose every date is unreadable', () {
    // Issue #1828's day-first fix leaves only genuinely unreadable dates
    // skipped. When that is every row, the Map Fields step used to show the
    // first raw transformer warning, in English: "Row 2: could not resolve
    // dateTime, skipping".
    setUp(setUpTestDatabase);
    tearDown(tearDownTestDatabase);

    const csv =
        'Date,Time,Max Depth\n'
        '15 Apr 2024,10:00,20\n'
        '16 Apr 2024,11:00,18\n';

    Future<UniversalImportNotifier> atMapFields({String? locale}) async {
      final notifier = await _notifier(locale: locale);
      notifier.state = notifier.state.copyWith(
        detectionResult: const DetectionResult(
          format: ImportFormat.csv,
          sourceApp: SourceApp.generic,
          confidence: 0.9,
        ),
        files: [
          PickedImportFile(
            name: 'logbook.csv',
            bytes: _bytes(csv),
            detection: const DetectionResult(
              format: ImportFormat.csv,
              confidence: 0.9,
            ),
            status: ImportFileStatus.pending,
          ),
        ],
      );
      await notifier.confirmSource();
      expect(notifier.state.currentStep, ImportWizardStep.fieldMapping);
      return notifier;
    }

    String summary(AppLocalizations l10n) => [
      l10n.universalImport_error_unreadableDatesHeadline(2),
      l10n.universalImport_summary_unreadableDatesRows(2, '2, 3'),
      l10n.universalImport_error_unreadableDatesHint,
    ].join('\n');

    test('counts the rows, names them, and points at the mapping', () async {
      final notifier = await atMapFields();

      await expectLater(
        notifier.confirmFieldMapping(),
        throwsA(
          isA<ImportStepFailure>().having(
            (e) => e.message,
            'message',
            summary(_en),
          ),
        ),
      );
      expect(notifier.state.error, summary(_en));
      expect(notifier.state.payload, isNull);
    });

    test('is written in the diver\'s language', () async {
      final notifier = await atMapFields(locale: 'de');

      await expectLater(
        notifier.confirmFieldMapping(),
        throwsA(isA<ImportStepFailure>()),
      );
      expect(notifier.state.error, summary(_de));
    });
  });

  group('duplicate detection is advisory', () {
    // No test database: every read the duplicate check makes throws
    // "Database not initialized". The import must still go through -- flagging
    // duplicates is a convenience, and losing it is no reason to make the file
    // unimportable.
    test('a failing duplicate check still produces the payload', () async {
      final notifier = await _notifier();
      _seed(notifier, _bytes(_oneDiveUddf));

      await notifier.confirmSource();

      expect(notifier.state.payload, isNotNull);
      expect(
        notifier.state.payload!.entitiesOf(ImportEntityType.dives),
        hasLength(1),
      );
      expect(notifier.state.duplicateResult, isNotNull);
      expect(notifier.state.duplicateResult!.hasDuplicates, isFalse);
      expect(notifier.state.isLoading, isFalse);
    });
  });
}
