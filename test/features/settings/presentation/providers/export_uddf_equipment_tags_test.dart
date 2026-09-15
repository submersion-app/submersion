import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Both full UDDF export paths pass each item's tag ids and every tag
/// definition those ids need (issue #1942).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String regId;
  late String rentalId;
  late String clubId;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.utc(2026, 3, 1);
    final divers = DiverRepository();
    await divers.createDiver(
      Diver(
        id: 'me',
        name: 'Me',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await divers.createDiver(
      Diver(id: 'other', name: 'Other', createdAt: now, updatedAt: now),
    );
    final reg = await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: '',
        diverId: 'me',
        name: 'Apeks XTX',
        type: EquipmentType.regulator,
      ),
    );
    final rental = await TagRepository().getOrCreateTag(
      'Rental',
      diverId: 'me',
      scope: TagScope.equipment,
    );
    // Another profile's tag on this diver's gear: the diver's own tag list
    // lacks it, so only the by-id lookup can supply its definition.
    final club = await TagRepository().getOrCreateTag(
      'Club kit',
      diverId: 'other',
      scope: TagScope.equipment,
    );
    await EquipmentTagRepository().replaceTags(reg.id, [rental.id, club.id]);
    regId = reg.id;
    rentalId = rental.id;
    clubId = club.id;
  });

  tearDown(tearDownTestDatabase);

  ProviderContainer make(_CapturingExportService export) {
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
    return container;
  }

  for (final save in [false, true]) {
    test('${save ? 'saving' : 'sharing'} passes item tag ids and their '
        'definitions', () async {
      final export = _CapturingExportService();
      final container = make(export);
      final notifier = container.read(exportNotifierProvider.notifier);
      await (save ? notifier.saveUddfToFile() : notifier.exportDivesToUddf());

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.success, reason: state.message);
      expect(export.tagIdsByItem!.keys, [regId]);
      expect(export.tagIdsByItem![regId], unorderedEquals([rentalId, clubId]));
      final ids = [for (final t in export.tags) t.id];
      expect(ids.where((id) => id == rentalId), hasLength(1));
      expect(ids, contains(clubId));
    });
  }
}

class _CapturingExportService implements ExportService {
  Map<String, List<String>>? tagIdsByItem;
  List<Tag> tags = const [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #exportAllDataToUddf || name == #saveAllDataToUddfFile) {
      tagIdsByItem =
          invocation.namedArguments[#equipmentTagIdsByItem]
              as Map<String, List<String>>;
      tags = invocation.namedArguments[#tags] as List<Tag>;
      return name == #exportAllDataToUddf
          ? Future<String>.value('/tmp/export.uddf')
          : Future<String?>.value('/tmp/export.uddf');
    }
    return null;
  }
}

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
