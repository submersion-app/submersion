import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/coordinate_format_picker.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Stands in for SettingsNotifier so the picker's saves can be inspected
/// without a database. Only setCoordinateFormat is exercised here.
class _RecordingSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  final List<CoordinateFormat> saved;

  _RecordingSettingsNotifier(super.initial, this.saved);

  @override
  Future<void> setCoordinateFormat(CoordinateFormat format) async {
    state = state.copyWith(coordinateFormat: format);
    saved.add(format);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late List<CoordinateFormat> saved;
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
            onPressed: () => showCoordinateFormatPicker(
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

  testWidgets('offers every format', (tester) async {
    await openPicker(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CoordinateFormatList)),
    );
    for (final format in CoordinateFormat.values) {
      expect(
        find.text(coordinateFormatLabel(l10n, format)),
        findsOneWidget,
        reason: 'missing an option for ${format.name}',
      );
    }
  });

  testWidgets('shows the same sample point rendered in each notation', (
    tester,
  ) async {
    await openPicker(tester);
    // The worked examples are what make the choice legible to a diver who
    // does not already know the notations by name.
    expect(find.text('20.361944° N, 87.029722° W'), findsOneWidget);
    expect(find.text("20° 21.717' N, 87° 01.783' W"), findsOneWidget);
    expect(find.text('16Q 496898E 2251535N'), findsOneWidget);
    expect(find.text('16Q DH 96898 51535'), findsOneWidget);
  });

  testWidgets('selecting a format saves it and closes', (tester) async {
    await openPicker(tester);
    await tester.tap(find.text('16Q DH 96898 51535'));
    await tester.pumpAndSettle();

    expect(saved, [CoordinateFormat.mgrs]);
    expect(find.text('16Q DH 96898 51535'), findsNothing);
  });
}
