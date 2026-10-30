import 'dart:async';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/settings/domain/list_arrangements.dart';
import 'package:submersion/features/settings/presentation/providers/list_arrangement_writes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../support/fake_app_settings_repository.dart';

/// The app-wide arrangement older builds saved, standing in for the
/// `equipment_arrangement` and `equipment_group_by_location` keys.
class _LegacyRepository extends FakeAppSettingsRepository {
  EquipmentArrangement? legacy;
  bool failRead = false;
  int reads = 0;

  @override
  Future<EquipmentArrangement?> getEquipmentArrangement() async {
    reads++;
    if (failRead) throw StateError('read failed');
    return legacy;
  }
}

/// Holds the settings load until [gate] completes, then lands [next] (a
/// diver switch), as the real notifier does.
class _SwitchingSettings extends MockSettingsNotifier {
  _SwitchingSettings(super.initial, this.next);

  final AppSettings next;
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> get settingsLoaded async {
    await gate.future;
    state = next;
  }
}

/// Equipment's gear arrangement and group-by-location switch belong to the
/// diver (issue #3748). A diver who never changed them here still sees the
/// app-wide value older builds saved, and their first change builds on it.
void main() {
  const headToToe = EquipmentArrangement(
    typeOrder: EquipmentTypeOrder.headToToe,
    groupByType: true,
    itemSortField: EquipmentItemSortField.name,
    itemSortDirection: SortDirection.ascending,
  );
  const flat = EquipmentArrangement(
    typeOrder: EquipmentTypeOrder.none,
    groupByType: false,
    itemSortField: EquipmentItemSortField.name,
    itemSortDirection: SortDirection.descending,
  );

  late MockSettingsNotifier settings;
  late _LegacyRepository repository;
  late ProviderContainer container;

  setUp(() {
    settings = MockSettingsNotifier();
    repository = _LegacyRepository();
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        appSettingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });
  tearDown(() => container.dispose());

  void ownArrangement(EquipmentArrangement a) =>
      settings.state = settings.state.copyWith(
        listArrangements: settings.state.listArrangements.copyWith(
          equipmentArrangement: encodeEquipmentArrangement(a),
        ),
      );

  Future<EquipmentArrangement> shown() async {
    await container.read(legacyEquipmentArrangementProvider.future);
    return container.read(equipmentArrangementProvider);
  }

  EquipmentArrangement? saved() => decodeEquipmentArrangement(
    settings.state.listArrangements.equipmentArrangement,
  );

  test('the codec round-trips and rejects garbage', () {
    expect(decodeEquipmentArrangement(encodeEquipmentArrangement(flat)), flat);
    expect(decodeEquipmentArrangement(null), isNull);
    expect(decodeEquipmentArrangement('not json'), isNull);
    expect(decodeEquipmentArrangement('[1]'), isNull);
  });

  test('per-diver value wins over legacy', () async {
    repository.legacy = headToToe;
    ownArrangement(flat);
    expect(await shown(), flat);
  });

  test('no per-diver value shows legacy', () async {
    repository.legacy = headToToe;
    expect(await shown(), headToToe);
  });

  test('neither gives defaults', () async {
    expect(await shown(), EquipmentArrangement.defaults);
  });

  test('switching diver switches the arrangement', () async {
    ownArrangement(flat);
    expect(await shown(), flat);
    settings.state = AppSettings(
      listArrangements: ListArrangements(
        equipmentArrangement: encodeEquipmentArrangement(headToToe),
      ),
    );
    expect(container.read(equipmentArrangementProvider), headToToe);
  });

  test('edit before legacy load builds on legacy value', () async {
    repository.legacy = headToToe;
    await settings.updateEquipmentArrangement(
      repository,
      (current) => current.copyWith(groupByType: false),
    );
    expect(saved(), headToToe.copyWith(groupByType: false));
  });

  test('an edit builds on the per-diver value when there is one', () async {
    repository.legacy = headToToe;
    ownArrangement(flat);
    await settings.updateEquipmentArrangement(
      repository,
      (current) => current.copyWith(groupByType: true),
    );
    expect(saved(), flat.copyWith(groupByType: true));
  });

  test('a diver with their own value never reads the app-wide one', () async {
    ownArrangement(flat);
    await settings.updateEquipmentArrangement(
      repository,
      (current) => current.copyWith(groupByType: true),
    );
    expect(repository.reads, 0);
    expect(saved(), flat.copyWith(groupByType: true));
  });

  test('the fallback order is own, then app-wide, then defaults', () {
    final own = encodeEquipmentArrangement(flat);
    expect(pickEquipmentArrangement(own, () => headToToe), flat);
    expect(pickEquipmentArrangement(null, () => headToToe), headToToe);
    expect(pickEquipmentArrangement('not json', () => headToToe), headToToe);
    expect(
      pickEquipmentArrangement(null, () => null),
      EquipmentArrangement.defaults,
    );
    var asked = false;
    pickEquipmentArrangement(own, () {
      asked = true;
      return headToToe;
    });
    expect(asked, isFalse, reason: 'own value: the app-wide one is not read');
  });

  test('an edit during a diver switch builds on the new diver', () async {
    // The previous diver had their own arrangement; the diver being switched
    // to has none and sees the app-wide one. Deciding before the load lands
    // would skip that read and save the defaults for the new diver.
    repository.legacy = headToToe;
    final switching = _SwitchingSettings(
      AppSettings(
        listArrangements: ListArrangements(
          equipmentArrangement: encodeEquipmentArrangement(flat),
        ),
      ),
      const AppSettings(),
    );
    final editing = switching.updateEquipmentArrangement(
      repository,
      (current) => current.copyWith(groupByType: false),
    );
    switching.gate.complete();
    await editing;

    expect(
      decodeEquipmentArrangement(
        switching.state.listArrangements.equipmentArrangement,
      ),
      headToToe.copyWith(groupByType: false),
    );
  });

  test('failed legacy read refuses the edit', () async {
    repository.failRead = true;
    await expectLater(
      settings.updateEquipmentArrangement(
        repository,
        (current) => current.copyWith(groupByType: false),
      ),
      throwsStateError,
    );
    expect(settings.state.listArrangements.equipmentArrangement, isNull);
  });

  test(
    'a failed legacy read does not block a diver with their own value',
    () async {
      repository.failRead = true;
      ownArrangement(flat);
      await settings.updateEquipmentArrangement(
        repository,
        (current) => current.copyWith(groupByType: true),
      );
      expect(saved(), flat.copyWith(groupByType: true));
    },
  );

  test('resolveEquipmentArrangement follows the same order', () async {
    expect(
      await resolveEquipmentArrangement(container.read),
      EquipmentArrangement.defaults,
    );
    repository.legacy = headToToe;
    expect(await resolveEquipmentArrangement(container.read), headToToe);
    ownArrangement(flat);
    expect(await resolveEquipmentArrangement(container.read), flat);
  });

  test('resolve reads providers only before it awaits', () async {
    // The PDF export passes a widget's ref.read; the widget can be gone by
    // the time the settings load lands.
    repository.legacy = headToToe;
    var gone = false;
    T read<T>(ProviderListenable<T> provider) {
      if (gone) throw StateError('ref used after the widget was unmounted');
      return container.read(provider);
    }

    final resolving = resolveEquipmentArrangement(read);
    gone = true;
    expect(await resolving, headToToe);
  });

  test('a failed legacy read resolves to the defaults', () async {
    repository.failRead = true;
    expect(
      await resolveEquipmentArrangement(container.read),
      EquipmentArrangement.defaults,
    );
  });

  group('group by location', () {
    test('falls back to legacy then false', () async {
      expect(
        await container.read(equipmentGroupByLocationProvider.future),
        isFalse,
      );
      repository.values['equipment_group_by_location'] = 'true';
      container.invalidate(equipmentGroupByLocationProvider);
      expect(
        await container.read(equipmentGroupByLocationProvider.future),
        isTrue,
      );
    });

    test('the per-diver value wins', () async {
      repository.values['equipment_group_by_location'] = 'true';
      await settings.setEquipmentGroupByLocation(false);
      expect(
        await container.read(equipmentGroupByLocationProvider.future),
        isFalse,
      );
    });
  });

  test('the saved JSON is the arrangement toJson', () {
    expect(jsonDecode(encodeEquipmentArrangement(flat)), flat.toJson());
  });
}
