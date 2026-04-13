import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';

import '../import_wizard/data/adapters/dive_computer_adapter_reimport_test.mocks.dart';

void main() {
  group(
    'Issue #206: Re-import surfaces all existing dives as pending duplicates',
    () {
      test('forceFullDownload=true on the adapter is preserved through the '
          'construct-and-read contract', () {
        // The contract this test enforces:
        // 1. DiveComputerAdapter exposes forceFullDownload as a public flag.
        // 2. Default is false (incremental download preserved).
        // 3. Constructor-provided true is preserved verbatim.
        //
        // Downstream coverage:
        // - dc_adapter_download_step_force_full_test.dart asserts the flag
        //   flips setNewDivesOnly(false) in the download step.
        // - import_wizard_notifier_test.dart asserts duplicate dives from
        //   the full download land in the Review step as pending.
        //
        // If this test fails, the re-import entry point is broken.

        final reimportAdapter = DiveComputerAdapter(
          importService: MockDiveImportService(),
          computerRepository: MockDiveComputerRepository(),
          diveRepository: MockDiveRepository(),
          diverId: 'diver-1',
          forceFullDownload: true,
        );
        expect(reimportAdapter.forceFullDownload, isTrue);

        final defaultAdapter = DiveComputerAdapter(
          importService: MockDiveImportService(),
          computerRepository: MockDiveComputerRepository(),
          diveRepository: MockDiveRepository(),
          diverId: 'diver-1',
        );
        expect(defaultAdapter.forceFullDownload, isFalse);
      });
    },
  );
}
