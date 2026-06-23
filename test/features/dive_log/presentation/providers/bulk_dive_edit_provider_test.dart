import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/bulk_dive_edit_provider.dart';

void main() {
  test('bulkDiveEditServiceProvider builds a BulkDiveEditService', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(bulkDiveEditServiceProvider);
    expect(service, isA<BulkDiveEditService>());
  });
}
