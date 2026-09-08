import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/mix_template_manager.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<WidgetRef> _pump(WidgetTester tester) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(const AppSettings()),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, _) {
                captured = ref;
                return const MixTemplateManager();
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('starts seeded with the templates named in issue #1100', (
    tester,
  ) async {
    final ref = await _pump(tester);
    expect(find.textContaining('No templates yet'), findsNothing);
    expect(
      ref.read(blenderTemplatesProvider),
      BlenderPreferences.seedTemplates,
    );
  });

  testWidgets('adding a valid mix appends it and persists', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderTemplatesProvider.notifier).state = const [];
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '21');
    await tester.enterText(find.byType(TextField).last, '35');
    await tester.tap(find.byTooltip('Add template'));
    await tester.pumpAndSettle();

    expect(ref.read(blenderTemplatesProvider), const [
      MixTemplate(o2: 21, he: 35),
    ]);
    expect(find.text('21/35'), findsOneWidget);
  });

  testWidgets('a duplicate is refused with a reason', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderTemplatesProvider.notifier).state = const [
      MixTemplate(o2: 10, he: 70),
    ];
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '10');
    await tester.enterText(find.byType(TextField).last, '70');
    await tester.tap(find.byTooltip('Add template'));
    await tester.pumpAndSettle();

    expect(find.text('That mix is already saved.'), findsOneWidget);
    expect(ref.read(blenderTemplatesProvider), hasLength(1));
  });

  testWidgets('an impossible mix is refused with a reason', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField).first, '60');
    await tester.enterText(find.byType(TextField).last, '70');
    await tester.tap(find.byTooltip('Add template'));
    await tester.pumpAndSettle();

    expect(find.textContaining('cannot exceed 100%'), findsOneWidget);
  });

  testWidgets('a blank box is reported as missing, not as an impossible mix', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Add template'));
    await tester.pumpAndSettle();

    expect(find.textContaining('as numbers'), findsOneWidget);
    expect(find.textContaining('cannot exceed 100%'), findsNothing);
  });

  testWidgets('the cap is refused with a reason', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderTemplatesProvider.notifier).state = List.generate(
      BlenderPreferences.maxTemplates,
      (i) => MixTemplate(o2: 10 + i * 0.1, he: 50),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '18');
    await tester.enterText(find.byType(TextField).last, '45');
    await tester.ensureVisible(find.byTooltip('Add template'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add template'));
    await tester.pumpAndSettle();

    expect(find.textContaining('You can save up to'), findsOneWidget);
    expect(
      ref.read(blenderTemplatesProvider),
      hasLength(BlenderPreferences.maxTemplates),
    );
  });

  testWidgets('deleting removes the template', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderTemplatesProvider.notifier).state = const [
      MixTemplate(o2: 10, he: 70),
    ];
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete 10/70'));
    await tester.pumpAndSettle();

    expect(ref.read(blenderTemplatesProvider), isEmpty);
  });
}
