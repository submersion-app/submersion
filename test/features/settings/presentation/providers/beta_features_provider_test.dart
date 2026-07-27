import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/beta_features_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('BetaFeaturesNotifier', () {
    test('initial state is false when no preference stored', () {
      final notifier = BetaFeaturesNotifier(prefs);
      expect(notifier.state, isFalse);
    });

    test('initial state reads true from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'beta_features_enabled': true});
      prefs = await SharedPreferences.getInstance();
      final notifier = BetaFeaturesNotifier(prefs);
      expect(notifier.state, isTrue);
    });

    test('setEnabled(true) updates state and persists', () async {
      final notifier = BetaFeaturesNotifier(prefs);
      await notifier.setEnabled(true);
      expect(notifier.state, isTrue);
      expect(prefs.getBool('beta_features_enabled'), isTrue);
    });

    test('setEnabled(false) updates state and persists', () async {
      final notifier = BetaFeaturesNotifier(prefs);
      await notifier.setEnabled(true);
      await notifier.setEnabled(false);
      expect(notifier.state, isFalse);
      expect(prefs.getBool('beta_features_enabled'), isFalse);
    });

    test('persists across notifier instances', () async {
      final first = BetaFeaturesNotifier(prefs);
      await first.setEnabled(true);
      final second = BetaFeaturesNotifier(prefs);
      expect(second.state, isTrue);
    });
  });

  group('betaFeaturesEnabledProvider', () {
    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('reads false by default', () {
      expect(makeContainer().read(betaFeaturesEnabledProvider), isFalse);
    });

    test('setEnabled updates provider state', () async {
      final container = makeContainer();
      await container
          .read(betaFeaturesEnabledProvider.notifier)
          .setEnabled(true);
      expect(container.read(betaFeaturesEnabledProvider), isTrue);
    });
  });
}
