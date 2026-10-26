import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/presentation/providers/import_job_provider.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/background_import_notice.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  String notice(ImportJobOutcomeKind kind, int dives) => backgroundImportNotice(
    l10n,
    ImportJobOutcome(kind: kind, importedDives: dives),
  );

  test('tells how an import that ran on alone ended', () {
    expect(
      notice(ImportJobOutcomeKind.finished, 12),
      'Import finished: 12 dives imported.',
    );
    expect(
      notice(ImportJobOutcomeKind.finished, 1),
      'Import finished: 1 dive imported.',
    );
    expect(
      notice(ImportJobOutcomeKind.stopped, 3),
      'Import stopped: 3 dives imported.',
    );
    expect(notice(ImportJobOutcomeKind.failed, 0), 'The import failed.');
  });
}
