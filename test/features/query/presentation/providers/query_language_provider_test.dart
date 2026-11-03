import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_language_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  String languageWith({required String locale, Locale? device}) {
    final container = ProviderContainer(
      overrides: [
        localeProvider.overrideWithValue(locale),
        exploreDeviceLocaleProvider.overrideWithValue(
          () => device ?? const Locale('en'),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(queryLanguageProvider);
  }

  test('reads the language the app is set to', () {
    expect(languageWith(locale: 'fr'), 'fr');
  });

  test('drops a region from the language', () {
    expect(languageWith(locale: 'pt-BR'), 'pt');
    expect(languageWith(locale: 'pt_BR'), 'pt');
  });

  test('system follows the device', () {
    expect(languageWith(locale: 'system', device: const Locale('de')), 'de');
    expect(
      languageWith(locale: 'system', device: const Locale('nl', 'BE')),
      'nl',
    );
  });
}
