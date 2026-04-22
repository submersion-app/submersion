import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';

/// Minimal concrete implementation for testing the abstract class defaults.
class _TestAdapter extends ImportSourceAdapter {
  final String _displayName;

  _TestAdapter({String displayName = 'Test Source'})
    : _displayName = displayName;

  @override
  ImportSourceType get sourceType => ImportSourceType.uddf;

  @override
  String get displayName => _displayName;

  @override
  List<WizardStepDef> get acquisitionSteps => [];

  @override
  Set<DuplicateAction> get supportedDuplicateActions => {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
  };

  @override
  Future<ImportBundle> buildBundle() async => const ImportBundle(
    source: ImportSourceInfo(type: ImportSourceType.uddf, displayName: 'test'),
    groups: {},
  );

  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) async => bundle;

  @override
  Future<UnifiedImportResult> performImport(
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions, {
    bool retainSourceDiveNumbers = false,
    ImportProgressCallback? onProgress,
    ImportCancellationToken? cancelToken,
  }) async => const UnifiedImportResult(
    importedCounts: {},
    consolidatedCount: 0,
    skippedCount: 0,
  );
}

void main() {
  group('ImportSourceAdapter.defaultTagName', () {
    test('includes display name and today\'s date', () {
      final adapter = _TestAdapter(displayName: 'Perdix');
      final tagName = adapter.defaultTagName;

      expect(tagName, startsWith('Perdix Import '));
      // Verify date format: YYYY-MM-DD
      final datePart = tagName.replaceFirst('Perdix Import ', '');
      expect(datePart, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('pads month and day with leading zeros', () {
      // We can't control DateTime.now(), but we can verify the format
      // is always zero-padded by checking the pattern
      final adapter = _TestAdapter();
      final tagName = adapter.defaultTagName;
      final datePart = tagName.replaceFirst('Test Source Import ', '');
      final parts = datePart.split('-');

      expect(parts, hasLength(3));
      expect(parts[0].length, 4); // year
      expect(parts[1].length, 2); // month (zero-padded)
      expect(parts[2].length, 2); // day (zero-padded)
    });

    test('uses display name with spaces correctly', () {
      final adapter = _TestAdapter(displayName: "Kiyan's Teric");
      expect(adapter.defaultTagName, startsWith("Kiyan's Teric Import "));
    });

    test('uses filename-style display name correctly', () {
      final adapter = _TestAdapter(displayName: 'dive_log.ssrf');
      expect(adapter.defaultTagName, startsWith('dive_log.ssrf Import '));
    });
  });

  group('ImportSourceAdapter.resetState', () {
    test('default implementation is a no-op', () {
      final adapter = _TestAdapter();
      // Should not throw
      adapter.resetState();
    });
  });
}
