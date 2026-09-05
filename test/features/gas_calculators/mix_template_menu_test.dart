import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/mix_template_menu.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<WidgetRef> _pump(
  WidgetTester tester, {
  List<MixTemplate> templates = const [],
  GasMix target = const GasMix(o2: 32),
  void Function(MixTemplate)? onSelected,
}) async {
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
          body: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return MixTemplateMenu(onSelected: onSelected ?? (_) {});
            },
          ),
        ),
      ),
    ),
  );
  captured.read(blenderTemplatesProvider.notifier).state = templates;
  captured.read(blenderTargetMixProvider.notifier).state = target;
  await tester.pumpAndSettle();
  return captured;
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.text('Templates'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('picking a template sets the target mix and notifies', (
    tester,
  ) async {
    MixTemplate? picked;
    final ref = await _pump(
      tester,
      templates: const [MixTemplate(o2: 10, he: 70)],
      onSelected: (t) => picked = t,
    );

    await _openMenu(tester);
    await tester.tap(find.text('10/70'));
    await tester.pumpAndSettle();

    expect(ref.read(blenderTargetMixProvider), const GasMix(o2: 10, he: 70));
    expect(picked, const MixTemplate(o2: 10, he: 70));
  });

  testWidgets(
    '"Adjust values" is disabled when the target mix matches no template',
    (tester) async {
      await _pump(
        tester,
        templates: const [MixTemplate(o2: 10, he: 70)],
        target: const GasMix(o2: 21),
      );

      await _openMenu(tester);
      await tester.tap(find.text('Adjust values'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    '"Adjust values" edits the template matching the current target mix',
    (tester) async {
      MixTemplate? picked;
      final ref = await _pump(
        tester,
        templates: const [
          MixTemplate(o2: 18, he: 45),
          MixTemplate(o2: 10, he: 70),
        ],
        target: const GasMix(o2: 10, he: 70),
        onSelected: (t) => picked = t,
      );

      await _openMenu(tester);
      await tester.tap(find.text('Adjust values'));
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '12');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Order is preserved: the edited mix replaces 10/70 in place rather
      // than moving to the end of the list.
      expect(ref.read(blenderTemplatesProvider), const [
        MixTemplate(o2: 18, he: 45),
        MixTemplate(o2: 12, he: 70),
      ]);
      expect(ref.read(blenderTargetMixProvider), const GasMix(o2: 12, he: 70));
      expect(picked, const MixTemplate(o2: 12, he: 70));
    },
  );

  testWidgets('editing a template into a duplicate is refused with a reason', (
    tester,
  ) async {
    final ref = await _pump(
      tester,
      templates: const [
        MixTemplate(o2: 18, he: 45),
        MixTemplate(o2: 10, he: 70),
      ],
      target: const GasMix(o2: 10, he: 70),
    );

    await _openMenu(tester);
    await tester.tap(find.text('Adjust values'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '18');
    await tester.enterText(find.byType(TextField).last, '45');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('That mix is already saved.'), findsOneWidget);
    expect(ref.read(blenderTemplatesProvider), hasLength(2));
  });

  testWidgets('"Save current mix" adds the current target as a new template', (
    tester,
  ) async {
    final ref = await _pump(tester, target: const GasMix(o2: 15, he: 40));

    await _openMenu(tester);
    await tester.tap(find.text('Save current mix'));
    await tester.pumpAndSettle();

    expect(ref.read(blenderTemplatesProvider), const [
      MixTemplate(o2: 15, he: 40),
    ]);
    expect(find.text('Saved 15/40'), findsOneWidget);
  });

  testWidgets('"Save current mix" refuses a mix that is already saved', (
    tester,
  ) async {
    final ref = await _pump(
      tester,
      templates: const [MixTemplate(o2: 10, he: 70)],
      target: const GasMix(o2: 10, he: 70),
    );

    await _openMenu(tester);
    await tester.tap(find.text('Save current mix'));
    await tester.pumpAndSettle();

    expect(find.text('That mix is already saved.'), findsOneWidget);
    expect(ref.read(blenderTemplatesProvider), hasLength(1));
  });
}
