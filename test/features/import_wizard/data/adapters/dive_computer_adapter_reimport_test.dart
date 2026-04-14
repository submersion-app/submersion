import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';

@GenerateMocks([DiveImportService, DiveComputerRepository, DiveRepository])
import 'dive_computer_adapter_reimport_test.mocks.dart';

void main() {
  late MockDiveImportService importService;
  late MockDiveComputerRepository computerRepo;
  late MockDiveRepository diveRepo;

  setUp(() {
    importService = MockDiveImportService();
    computerRepo = MockDiveComputerRepository();
    diveRepo = MockDiveRepository();
  });

  group('forceFullDownload field', () {
    test('defaults to false when not specified', () {
      final adapter = DiveComputerAdapter(
        importService: importService,
        computerRepository: computerRepo,
        diveRepository: diveRepo,
        diverId: 'diver-1',
      );
      expect(adapter.forceFullDownload, isFalse);
    });

    test('reflects constructor-provided true', () {
      final adapter = DiveComputerAdapter(
        importService: importService,
        computerRepository: computerRepo,
        diveRepository: diveRepo,
        diverId: 'diver-1',
        forceFullDownload: true,
      );
      expect(adapter.forceFullDownload, isTrue);
    });

    test('reflects constructor-provided false', () {
      final adapter = DiveComputerAdapter(
        importService: importService,
        computerRepository: computerRepo,
        diveRepository: diveRepo,
        diverId: 'diver-1',
        forceFullDownload: false,
      );
      expect(adapter.forceFullDownload, isFalse);
    });
  });
}
