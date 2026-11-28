import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// diver_settings.preferred_currency_codes round trip (issue #4997).
void main() {
  late DiverSettingsRepository repository;

  Future<void> insertDiver(String id) =>
      DatabaseService.instance.database.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        "VALUES ('$id', '$id', 1000, 1000)",
      );

  /// The raw column of the only settings row.
  Future<String?> storedRaw() async {
    final row = await DatabaseService.instance.database
        .customSelect('SELECT preferred_currency_codes FROM diver_settings')
        .getSingle();
    return row.read<String?>('preferred_currency_codes');
  }

  Future<void> storeRaw(String diverId, String raw) =>
      DatabaseService.instance.database.customStatement(
        'UPDATE diver_settings SET preferred_currency_codes = ? '
        'WHERE diver_id = ?',
        [raw, diverId],
      );

  setUp(() async {
    await setUpTestDatabase();
    await insertDiver('d1');
    repository = DiverSettingsRepository();
  });

  tearDown(tearDownTestDatabase);

  test('a new diver follows the built-in defaults, stored as null', () async {
    await repository.createSettingsForDiver('d1');
    final settings = await repository.getSettingsForDiver('d1');
    expect(settings!.preferredCurrencyCodes, kDefaultPreferredCurrencyCodes);
    expect(await storedRaw(), isNull);
  });

  test('create and update round trip the codes in their order', () async {
    await repository.createSettingsForDiver(
      'd1',
      settings: const AppSettings(preferredCurrencyCodes: ['BRL', 'USD']),
    );
    var settings = await repository.getSettingsForDiver('d1');
    expect(settings!.preferredCurrencyCodes, ['BRL', 'USD']);

    final updated = settings.copyWith(preferredCurrencyCodes: ['EUR', 'BRL']);
    await repository.updateSettingsForDiver('d1', updated, previous: settings);
    settings = await repository.getSettingsForDiver('d1');
    expect(settings!.preferredCurrencyCodes, ['EUR', 'BRL']);
  });

  test('an empty choice survives the round trip', () async {
    await repository.createSettingsForDiver(
      'd1',
      settings: const AppSettings(preferredCurrencyCodes: []),
    );
    final settings = await repository.getSettingsForDiver('d1');
    expect(settings!.preferredCurrencyCodes, isEmpty);
  });

  test('a malformed stored value reads as the defaults', () async {
    await repository.createSettingsForDiver('d1');
    for (final raw in ['not json', '{"a":1}']) {
      await storeRaw('d1', raw);
      expect(
        (await repository.getSettingsForDiver('d1'))!.preferredCurrencyCodes,
        kDefaultPreferredCurrencyCodes,
      );
    }
  });

  test('stored codes are normalised on read', () async {
    await repository.createSettingsForDiver('d1');
    await storeRaw('d1', '[" brl","brl",3,"EUR"]');
    expect(
      (await repository.getSettingsForDiver('d1'))!.preferredCurrencyCodes,
      ['BRL', 'EUR'],
    );
  });

  test('another order stores different settings', () {
    expect(
      DiverSettingsRepository.storesSameSettings(
        const AppSettings(preferredCurrencyCodes: ['BRL', 'EUR']),
        const AppSettings(preferredCurrencyCodes: ['EUR', 'BRL']),
      ),
      isFalse,
    );
    expect(
      DiverSettingsRepository.storesSameSettings(
        const AppSettings(
          preferredCurrencyCodes: [...kDefaultPreferredCurrencyCodes],
        ),
        const AppSettings(),
      ),
      isTrue,
    );
  });

  test('encode and decode are inverse', () {
    expect(
      encodePreferredCurrencyCodes(kDefaultPreferredCurrencyCodes),
      isNull,
    );
    expect(decodePreferredCurrencyCodes(null), kDefaultPreferredCurrencyCodes);
    expect(decodePreferredCurrencyCodes(''), kDefaultPreferredCurrencyCodes);
    expect(
      decodePreferredCurrencyCodes(encodePreferredCurrencyCodes(['BRL'])),
      ['BRL'],
    );
    expect(decodePreferredCurrencyCodes(encodePreferredCurrencyCodes([])), []);
  });

  test('a non-empty list with no valid code reads as the defaults', () {
    expect(decodePreferredCurrencyCodes('[3]'), kDefaultPreferredCurrencyCodes);
    expect(
      decodePreferredCurrencyCodes('["EU"]'),
      kDefaultPreferredCurrencyCodes,
    );
  });
}
