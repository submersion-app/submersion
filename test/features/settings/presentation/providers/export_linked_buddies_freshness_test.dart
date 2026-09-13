import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/pdf_text.dart';
import '../../../../helpers/test_database.dart';

/// Issue #1861: once the CSV and PADI exports print linked buddies, they must
/// print the CURRENT names. [divesProvider] only refreshes on `dives` table
/// writes, and renaming a buddy writes `buddies` alone, so an export that read
/// the cached list printed the old name until some dive happened to change.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Buddy buddy;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.utc(2026, 3, 1);
    await DiverRepository().createDiver(
      Diver(
        id: 'me',
        name: 'Me',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final dive = await DiveRepository().createDive(
      Dive(id: '', diverId: 'me', diveNumber: 7, dateTime: now),
    );
    buddy = await BuddyRepository().createBuddy(
      Buddy(id: '', diverId: 'me', name: 'Ana', createdAt: now, updatedAt: now),
    );
    await BuddyRepository().addBuddyToDive(dive.id, buddy.id, DiveRole.buddyId);
  });

  tearDown(tearDownTestDatabase);

  /// A container whose dive list has already been read, as it is once any
  /// screen showing the logbook has rendered, and whose linked buddy has since
  /// been renamed.
  Future<ProviderContainer> containerAfterRename(
    _CapturingExportService export,
  ) async {
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier()..state = 'me',
        ),
        settingsProvider.overrideWith((ref) => _FixedSettings()),
        exportServiceProvider.overrideWithValue(export),
      ],
    );
    addTearDown(container.dispose);

    final warm = await container.read(divesProvider.future);
    expect(warm.single.buddies.single.buddy.name, 'Ana');

    await BuddyRepository().updateBuddy(buddy.copyWith(name: 'Anna'));
    return container;
  }

  for (final save in [false, true]) {
    final path = save ? 'saving' : 'sharing';

    test('$path the dives CSV prints the renamed buddy', () async {
      final export = _CapturingExportService();
      final container = await containerAfterRename(export);
      final notifier = container.read(exportNotifierProvider.notifier);
      await (save
          ? notifier.saveDivesCsvToFile()
          : notifier.exportDivesToCsv());

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.success, reason: state.message);
      expect(export.csvDives.single.buddies.single.buddy.name, 'Anna');
    });

    test('$path the PADI logbook prints the renamed buddy', () async {
      final export = _CapturingExportService();
      final container = await containerAfterRename(export);
      final notifier = container.read(exportNotifierProvider.notifier);
      const options = PdfExportOptions(template: PdfTemplate.padiStyle);
      await (save
          ? notifier.savePdfToFile(options)
          : notifier.exportDivesToPdf(options));

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.success, reason: state.message);
      final text = pdfVisibleText(export.pdfBytes);
      expect(text, contains('Buddy: Anna'));
    });
  }
}

class _CapturingExportService implements ExportService {
  List<Dive> csvDives = const [];
  List<int> pdfBytes = const [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #exportDivesToCsv || name == #saveDivesCsvToFile) {
      csvDives = invocation.positionalArguments.first as List<Dive>;
      return name == #exportDivesToCsv
          ? Future<String>.value('/tmp/dives.csv')
          : Future<String?>.value('/tmp/dives.csv');
    }
    if (name == #sharePdfBytes || name == #savePdfBytesToFile) {
      pdfBytes = invocation.positionalArguments.first as List<int>;
      return name == #sharePdfBytes
          ? Future<String>.value('/tmp/logbook.pdf')
          : Future<String?>.value('/tmp/logbook.pdf');
    }
    // Any other delivery is a path these tests did not expect: fail loudly.
    return super.noSuchMethod(invocation);
  }
}

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
