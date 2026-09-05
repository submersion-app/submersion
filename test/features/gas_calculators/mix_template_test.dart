import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
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
  // Issue #1335 follow-up: adding, editing and deleting templates moved to
  // MixTemplateManager under Settings -> Trimix Mixer. This menu is now a
  // plain picker onto whatever is saved there.
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

  testWidgets('an emptied list shows the empty message', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderTemplatesProvider.notifier).state = const [];
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MixTemplateMenu));
    await tester.pumpAndSettle();
    expect(find.textContaining('No templates yet'), findsOneWidget);
  });
}
