import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/app_shortcuts.dart';
import 'package:submersion/core/accessibility/shortcut_registry.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

class _Engine implements NlEngine {
  _Engine(this.answer);
  final Future<NlAvailability> answer;

  @override
  Future<NlAvailability> availability(String localeTag) => answer;
  @override
  Future<void> prepare() async {}
  @override
  Stream<double> download() => const Stream.empty();
  @override
  Future<String> compile(String sentence, {required String localeTag}) =>
      throw UnimplementedError();
}

/// Ctrl+E (Cmd+E on macOS) opens Explore only where it can run. The first
/// press must not be lost to a probe that has not answered yet, and a device
/// without the model says why instead of doing nothing.
void main() {
  Future<GoRouter> pumpHost(
    WidgetTester tester,
    Future<NlAvailability> answer,
  ) async {
    final router = GoRouter(
      initialLocation: '/dives',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (context, state) => Scaffold(
            body: CallbackShortcuts(
              bindings: AppShortcuts.globalBindings(context),
              child: const Focus(autofocus: true, child: Text('Dive list')),
            ),
          ),
          routes: [
            GoRoute(path: 'explore', builder: (_, _) => const Text('Explore')),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nlEngineProvider.overrideWithValue(_Engine(answer)),
          localeProvider.overrideWithValue('en'),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> pressExplore(WidgetTester tester) async {
    final modifier = defaultTargetPlatform == TargetPlatform.macOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(modifier);
    await tester.pump();
  }

  testWidgets('a press before the probe answers still opens Explore', (
    tester,
  ) async {
    final probe = Completer<NlAvailability>();
    await pumpHost(tester, probe.future);

    await pressExplore(tester);
    expect(find.text('Explore'), findsNothing);

    probe.complete(NlAvailability.available);
    await tester.pumpAndSettle();
    expect(find.text('Explore'), findsOneWidget);
  });

  testWidgets('a device without the model says so', (tester) async {
    await pumpHost(tester, Future.value(NlAvailability.deviceNotEligible));

    await pressExplore(tester);
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsNothing);
    expect(
      find.text(AppLocalizationsEn().explore_shortcut_unavailable),
      findsOneWidget,
    );
  });

  testWidgets(
    'a platform with no model adapter neither lists nor binds the key',
    (tester) async {
      ShortcutCatalog.instance.clear();
      AppShortcuts.debugReset();
      // Put the catalog back as a fresh registration would fill it, for
      // whichever test file runs next in this isolate.
      addTearDown(() {
        ShortcutCatalog.instance.clear();
        AppShortcuts.debugReset();
      });

      await pumpHost(tester, Future.value(NlAvailability.available));

      expect(
        ShortcutCatalog.instance.entries.map((e) => e.label),
        isNot(contains('Explore with a sentence')),
      );
      await pressExplore(tester);
      await tester.pumpAndSettle();
      expect(find.text('Explore'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
