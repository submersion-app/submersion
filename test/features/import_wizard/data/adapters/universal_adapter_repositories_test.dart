import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';

import '../../../../helpers/test_database.dart';

/// The repositories a real UDDF import runs with. The optional ones are
/// optional for legacy callers only; a production import must supply
/// each, or the entities they own are silently skipped.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  testWidgets('a real import supplies the check-in repository', (tester) async {
    ImportRepositories? repos;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            repos = universalImportRepositories(ref);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(repos!.equipmentObservationRepository, isNotNull);
    expect(repos!.serviceRecordRepository, isNotNull);
  });
}
