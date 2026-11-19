import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';

import 'dive_computer_adapter_test.mocks.dart';

/// Issue #3022: a downloaded dive whose computer reported no start time
/// carries a stand-in time, and the download places it in no trip, so its
/// review row must say it has no time of its own.
void main() {
  test('a dive with no reported start time is marked so on its row', () async {
    final now = DateTime(2026, 3, 20);
    final importService = MockDiveImportService();
    when(importService.unmatchedTransmitterSerials).thenReturn(const []);
    final adapter = DiveComputerAdapter(
      importService: importService,
      computerRepository: MockDiveComputerRepository(),
      diveRepository: MockDiveRepository(),
      consolidationService: MockDiveConsolidationService(),
      diverId: 'diver-1',
      knownComputer: DiveComputer(
        id: 'computer-1',
        name: 'My Perdix',
        createdAt: now,
        updatedAt: now,
      ),
    );
    DownloadedDive download({required bool reported}) => DownloadedDive(
      startTime: DateTime(2026, 3, 10, 9),
      startTimeReported: reported,
      durationSeconds: 47 * 60,
      maxDepth: 32.4,
      profile: const [],
      tanks: const [],
    );
    adapter.setDownloadedDives([
      download(reported: true),
      download(reported: false),
    ]);

    final bundle = await adapter.buildBundle();

    final items = bundle.groups[ImportEntityType.dives]!.items;
    expect(items.map((i) => i.hasSourceTime), [true, false]);
  });
}
