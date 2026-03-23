import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

@GenerateMocks([DiveComputerRepository, DiveComputerService])
import 'download_notifier_fingerprint_test.mocks.dart';

void main() {
  late MockDiveComputerRepository mockRepository;
  late MockDiveComputerService mockService;
  late DownloadNotifier notifier;

  setUp(() {
    mockRepository = MockDiveComputerRepository();
    mockService = MockDiveComputerService();

    when(mockService.downloadEvents).thenAnswer((_) => const Stream.empty());

    notifier = DownloadNotifier(
      service: mockService,
      repository: mockRepository,
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  group('fingerprint logic in startDownload', () {
    test('newDivesOnly defaults to true', () {
      expect(notifier.state.newDivesOnly, isTrue);
    });

    test('setNewDivesOnly updates state', () {
      notifier.setNewDivesOnly(false);
      expect(notifier.state.newDivesOnly, isFalse);

      notifier.setNewDivesOnly(true);
      expect(notifier.state.newDivesOnly, isTrue);
    });
  });
}
