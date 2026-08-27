import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/place_name_language_picker.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Stands in for SettingsNotifier so the picker's saves can be inspected
/// without a database. Only setPlaceNameLanguage is exercised here.
class _RecordingSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  final List<String> saved;

  _RecordingSettingsNotifier(super.initial, this.saved);

  @override
  Future<void> setPlaceNameLanguage(String code) async {
    state = state.copyWith(placeNameLanguage: code);
    saved.add(code);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late List<String> saved;
  late ProviderContainer container;

  setUp(() {
    saved = [];
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _RecordingSettingsNotifier(const AppSettings(), saved),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Widget host(Widget child) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  Future<void> openPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showPlaceNameLanguagePicker(
              context,
              ref,
              container.read(settingsProvider),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers every supported language by its native name', (
    tester,
  ) async {
    await openPicker(tester);
    for (final name in ['English', 'Deutsch', 'Español', 'Magyar', '简体中文']) {
      expect(find.text(name), findsOneWidget, reason: 'missing $name');
    }
    expect(find.text('System Default'), findsNothing);
  });

  testWidgets('marks the current language', (tester) async {
    await openPicker(tester);
    final tile = find.ancestor(
      of: find.text('English'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: tile, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  testWidgets('selecting a language saves it and closes', (tester) async {
    await openPicker(tester);
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();

    expect(saved, ['de']);
    expect(find.byType(PlaceNameLanguageList), findsNothing);
  });

  test('the label is the native name, falling back to the code', () {
    expect(placeNameLanguageLabel('de'), 'Deutsch');
    expect(placeNameLanguageLabel('en'), 'English');
    expect(placeNameLanguageLabel('xx'), 'xx');
  });
}
