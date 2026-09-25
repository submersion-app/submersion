import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/lenses/connection_lens.dart';
import 'package:submersion/features/connections/presentation/providers/connections_lens_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('defaults to Dive circle when nothing is stored', () async {
    final c = await containerWith({});
    expect(c.read(connectionsLensProvider), LensSelection.fallback);
  });

  test('restores a stored lens id and a stored custom pair', () async {
    final c1 = await containerWith({'connections_last_lens': 'where'});
    expect(c1.read(connectionsLensProvider).lensId, 'where');
    final c2 = await containerWith({
      'connections_last_lens': 'custom:equipment:trip',
    });
    expect(c2.read(connectionsLensProvider).kindA, ConnectionKind.equipment);
    expect(c2.read(connectionsLensProvider).kindB, ConnectionKind.trip);
  });

  test('garbage in storage falls back', () async {
    final c = await containerWith({'connections_last_lens': 'custom:x'});
    expect(c.read(connectionsLensProvider), LensSelection.fallback);
  });

  test('select persists and notifies', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
    );
    addTearDown(c.dispose);
    c
        .read(connectionsLensProvider.notifier)
        .select(const LensSelection.lens(ConnectionLens.where));
    expect(c.read(connectionsLensProvider).lensId, 'where');
    expect(sp.getString('connections_last_lens'), 'where');
  });
}
