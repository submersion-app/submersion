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
          body: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return MixTemplateMenu(onSelected: (_) {});
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('lists the seeded templates', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    for (final label in ['7/75', '10/70', '12/60', '15/55', '18/35']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('selecting a template writes the target mix', (tester) async {
    final ref = await _pump(tester);
    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10/70'));
    await tester.pumpAndSettle();

    final target = ref.read(blenderTargetMixProvider);
    expect(target.o2, 10);
    expect(target.he, 70);
  });

  testWidgets('saving the current mix appends it', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderTargetMixProvider.notifier).state = const GasMix(
      o2: 21,
      he: 35,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save current mix'));
    await tester.pumpAndSettle();

    expect(
      ref.read(blenderTemplatesProvider).last,
      const MixTemplate(o2: 21, he: 35),
    );
  });

  testWidgets('saving a duplicate says so and adds nothing', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderTargetMixProvider.notifier).state = const GasMix(
      o2: 10,
      he: 70,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save current mix'));
    await tester.pumpAndSettle();

    expect(find.text('That mix is already saved.'), findsOneWidget);
    expect(ref.read(blenderTemplatesProvider), hasLength(5));
  });

  testWidgets('an emptied list shows the empty message', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderTemplatesProvider.notifier).state = const [];
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    expect(find.textContaining('No templates yet'), findsOneWidget);
  });

  testWidgets('the manage dialog deletes a template', (tester) async {
    final ref = await _pump(tester);
    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage templates'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete 10/70'));
    await tester.pumpAndSettle();

    expect(
      ref.read(blenderTemplatesProvider).map((t) => t.label),
      isNot(contains('10/70')),
    );
    expect(ref.read(blenderTemplatesProvider), hasLength(4));
  });
  testWidgets('the manage dialog says why an add was refused', (tester) async {
    // Raised in review on PR #1215: the dialog used to return quietly, which
    // reads as a broken button, while the menu explained itself.
    await _pump(tester);
    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage templates'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '10');
    await tester.enterText(find.byType(TextField).last, '70');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add template'));
    await tester.pumpAndSettle();

    expect(find.text('That mix is already saved.'), findsOneWidget);
  });

  testWidgets('the manage dialog confirms a successful add', (tester) async {
    final ref = await _pump(tester);
    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage templates'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '21');
    await tester.enterText(find.byType(TextField).last, '35');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add template'));
    await tester.pumpAndSettle();

    expect(find.textContaining('21/35'), findsWidgets);
    expect(
      ref.read(blenderTemplatesProvider).last,
      const MixTemplate(o2: 21, he: 35),
    );
  });
  testWidgets('a blank box is reported as missing, not as an impossible mix', (
    tester,
  ) async {
    // Raised in review on PR #1215: an empty field showed "O2 + He cannot
    // exceed 100%", which sends the user looking for a problem that is not
    // there.
    await _pump(tester);
    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage templates'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add template'));
    await tester.pumpAndSettle();

    expect(find.textContaining('as numbers'), findsOneWidget);
    expect(find.textContaining('cannot exceed 100%'), findsNothing);
  });

  testWidgets('an impossible mix still says so', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage templates'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '60');
    await tester.enterText(find.byType(TextField).last, '70');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add template'));
    await tester.pumpAndSettle();

    expect(find.textContaining('cannot exceed 100%'), findsOneWidget);
  });
}
