import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';

import '../../../../helpers/batched_read_expectations.dart';
import '../../../../helpers/export_logbook_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Issue #1867: the logbook and course PDFs read every dive's signatures in
/// one statement instead of one per dive.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(tearDownTestDatabase);

  group('SignatureStorageService.getSignaturesForDives', () {
    batchedReadTests(
      seed: () async {
        await seedExportLogbook(diveCount: 3);
        return ['dive-0', 'dive-1', 'dive-2', 'dive-bare'];
      },
      batched: (ids) => SignatureStorageService().getSignaturesForDives(ids),
      single: (id) => SignatureStorageService().getAllSignaturesForDive(id),
      holdsNothing: (signatures) => signatures.isEmpty,
    );
  });
}
