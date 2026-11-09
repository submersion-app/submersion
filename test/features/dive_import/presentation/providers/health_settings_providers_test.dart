import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_import/presentation/providers/health_settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The Apple Health switches (issue #637) live on this device and belong to
/// the diver who turned them on: nothing from Health is written to another
/// diver's dives, even after the app switches divers.
void main() {
  late SharedPreferences prefs;
  var divers = {'a', 'b'};

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    divers = {'a', 'b'};
  });

  HealthSettingsNotifier notifier() => HealthSettingsNotifier(
    prefs,
    diverExists: (id) async => divers.contains(id),
  );

  test('turning a switch on binds it to the diver', () async {
    final n = notifier();

    await n.enableAutoImport('a');
    await n.enableMetrics('b');

    expect(n.state.autoImportDiverId, 'a');
    expect(n.state.metricsDiverId, 'b');
  });

  test('the binding survives a restart, whoever the app shows', () async {
    await notifier().enableAutoImport('a');

    final reopened = notifier();
    await reopened.verifyBoundDivers();

    expect(reopened.state.autoImportDiverId, 'a');
  });

  test('turning a switch off forgets its diver', () async {
    final n = notifier();
    await n.enableAutoImport('a');
    await n.enableMetrics('a');

    await n.disableAutoImport();
    await n.disableMetrics();

    expect(n.state.autoImportDiverId, isNull);
    expect(n.state.metricsDiverId, isNull);
    expect(notifier().state.autoImportDiverId, isNull);
  });

  test(
    'a switch turned on while the bound divers are checked stays on',
    () async {
      await notifier().enableAutoImport('a');
      final lookup = Completer<bool>();
      final n = HealthSettingsNotifier(
        prefs,
        diverExists: (_) => lookup.future,
      );

      final verifying = n.verifyBoundDivers();
      await n.enableMetrics('b');
      lookup.complete(true);
      await verifying;

      expect(n.state.autoImportDiverId, 'a');
      expect(n.state.metricsDiverId, 'b');
      expect(prefs.getString(SettingsKeys.healthMetricsDiver), 'b');
    },
  );

  test('a deleted bound diver turns the switches off', () async {
    final n = notifier();
    await n.enableAutoImport('a');
    await n.enableMetrics('a');
    divers = {'b'};

    await n.verifyBoundDivers();

    expect(n.state.autoImportDiverId, isNull);
    expect(n.state.metricsDiverId, isNull);
    expect(notifier().state.autoImportDiverId, isNull);
  });
}
