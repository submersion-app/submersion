import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every place the app opens a file picker, the share sheet, a save dialog or
/// a drop target either explains demo mode's seal or is already behind it
/// (issue #3708).
///
/// A file that calls one of [_openings] must also call `demoSealGuard(` (a
/// control that shows the note) or `ensureNotDemo(` (an engine method that
/// refuses), or be listed in [_exemptions] with the reason it needs neither.
final _openings = RegExp(
  r'FilePicker\.|ImagePicker\(|SharePlus\.instance|getDirectoryPath\(|'
  r'\bDropTarget\(',
);

const _exemptions = <String, String>{
  'lib/core/presentation/pages/startup_page.dart':
      'startup recovery for the user\'s own database, before demo mode opens',
  'lib/core/services/database_location_service.dart':
      'pickCustomFolder serves only the sealed /settings/storage page and '
      'the gated migrate/switch methods',
  'lib/features/backup/presentation/widgets/backup_actions.dart':
      'behind the sealed /settings/backup route; backup and restore are '
      'gated in the engine',
  'lib/features/import_wizard/presentation/widgets/photo_folder_step.dart':
      'a step of the sealed /transfer import wizard',
  'lib/features/import_wizard/presentation/widgets/suunto_file_step.dart':
      'a step of the sealed /transfer import wizard',
  'lib/features/universal_import/presentation/providers/universal_import_providers.dart':
      'picks files only for the sealed /transfer import wizard',
  'lib/features/ocr_import/presentation/pages/ocr_scan_page.dart':
      'the sealed /dives/scan page',
  'lib/features/setup_wizard/presentation/widgets/steps/restore_step.dart':
      'first run and the sealed setup assistant only; restore is gated in '
      'the engine',
  'lib/features/shared_library/presentation/pages/connect_shared_library_page.dart':
      'behind the sealed /settings/shared-libraries route',
  'lib/features/shared_library/presentation/pages/library_backups_page.dart':
      'behind the sealed /settings/shared-libraries route',
  'lib/features/settings/presentation/providers/debug_log_providers.dart':
      'shares the diagnostic log for a bug report, not logbook data',
};

/// Export and re-import handlers that reach a sealed engine method through
/// their own sheets rather than a picker or the shared destination sheet.
/// Each must explain the seal before it does any work, or the engine's
/// refusal surfaces as a raw exception in an error snackbar.
const _guardedHandlers = <(String, String)>[
  (
    'lib/features/dive_log/presentation/pages/dive_detail_page.dart',
    'Future<void> _exportProfileChart(',
  ),
  (
    'lib/features/dive_log/presentation/pages/dive_detail_page.dart',
    'Future<void> _exportDiveDetailsPage(',
  ),
  (
    'lib/features/dive_log/presentation/pages/dive_detail_page.dart',
    'Future<void> _exportDivePdf(',
  ),
  (
    'lib/features/dive_log/presentation/pages/dive_detail_page.dart',
    'Future<void> _resyncDive(',
  ),
  (
    'lib/features/gas_calculators/presentation/widgets/blender/blender_invoice_card.dart',
    'Future<void> _openExportSheet(',
  ),
  (
    'lib/shared/widgets/export_destination_sheet.dart',
    'showExportDestinationSheetWithOptions(',
  ),
  // Photo and document imports that reach a gated service through a
  // helper, so no picker call in their own file would flag them.
  (
    'lib/features/media/presentation/pages/photo_picker_page.dart',
    'Future<List<AssetInfo>?> showPhotoPicker(',
  ),
  (
    'lib/features/dive_log/presentation/pages/dive_detail_page.dart',
    'Future<void> _scanGalleryForDive(',
  ),
  (
    'lib/features/trips/presentation/pages/trip_gallery_page.dart',
    'Future<void> _showScanDialog(',
  ),
  (
    'lib/features/trips/presentation/helpers/trip_scan_actions.dart',
    'Future<void> scanGalleryForTripPhotos(',
  ),
  (
    'lib/features/documents/presentation/pages/document_edit_page.dart',
    'Future<void> _addPage(',
  ),
  (
    'lib/features/media/presentation/helpers/media_link_replacer.dart',
    'Future<bool> replaceMediaLink(',
  ),
];

String _withoutComments(String code) => code
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('every picker, share and drop target is sealed or explained', () {
    final unsealed = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/features/demo_mode/') ||
          path.endsWith('.g.dart') ||
          _exemptions.containsKey(path)) {
        continue;
      }
      final code = _withoutComments(entity.readAsStringSync());
      if (!_openings.hasMatch(code)) continue;
      if (code.contains('demoSealGuard(') || code.contains('ensureNotDemo(')) {
        continue;
      }
      unsealed.add(path);
    }

    expect(
      unsealed,
      isEmpty,
      reason:
          'Guard each control with demoSealGuard(context, feature), gate the '
          'engine method with DemoModeGate.instance.ensureNotDemo(feature), or '
          'add an exemption with its reason',
    );
  });

  test('every exemption still names a file that opens something', () {
    for (final path in _exemptions.keys) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: path);
      expect(
        _openings.hasMatch(_withoutComments(file.readAsStringSync())),
        isTrue,
        reason: path,
      );
    }
  });

  for (final (path, signature) in _guardedHandlers) {
    test('$path $signature explains the seal before any work', () {
      final code = File(path).readAsStringSync();
      final at = code.indexOf(signature);
      expect(at, isNonNegative, reason: 'declaration not found');
      final body = code.substring(at);
      final guardAt = body.indexOf('demoSealGuard(');
      // Work is anything the user would see or wait for: an await, a sheet,
      // a dialog or a pushed page.
      final workAt = body.indexOf(
        RegExp(r'\bawait\b|showModalBottomSheet|showDialog|Navigator\.of\('),
      );
      expect(guardAt, isNonNegative, reason: 'no demoSealGuard( in $signature');
      expect(
        workAt < 0 || guardAt < workAt,
        isTrue,
        reason: 'the guard must come first',
      );
    });
  }
}
