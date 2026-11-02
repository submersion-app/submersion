import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The legend's own Annotations toggle (#4109): on by default and
/// independent of the Events toggle, so hiding the computer's events keeps
/// the diver's own.
void main() {
  test('showAnnotations defaults on and toggles independently of events', () {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _StubSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(profileLegendProvider, (_, _) {});
    addTearDown(sub.close);
    final notifier = container.read(profileLegendProvider.notifier);

    expect(container.read(profileLegendProvider).showAnnotations, isTrue);
    notifier.toggleEvents();
    expect(container.read(profileLegendProvider).showEvents, isFalse);
    expect(container.read(profileLegendProvider).showAnnotations, isTrue);

    notifier.toggleAnnotations();
    expect(container.read(profileLegendProvider).showAnnotations, isFalse);
    expect(container.read(profileLegendProvider).showEvents, isFalse);
    notifier.toggleAnnotations();
    expect(container.read(profileLegendProvider).showAnnotations, isTrue);
  });

  test('copyWith and equality carry showAnnotations', () {
    const a = ProfileLegendState();
    final b = a.copyWith(showAnnotations: false);
    expect(b.showAnnotations, isFalse);
    expect(b, isNot(equals(a)));
    expect(b.copyWith(showAnnotations: true), equals(a));
  });
}
