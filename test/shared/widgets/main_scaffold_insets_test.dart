import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/edit_form_scaffold.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/responsive_form_columns.dart';
import 'package:submersion/shared/widgets/main_scaffold.dart';
import 'package:submersion/shared/widgets/shell_chrome_scope.dart';

const _screen = Size(390, 844);
const _keyboard = 330.0;

class _StubUpdateStatusNotifier extends StateNotifier<UpdateStatus>
    implements UpdateStatusNotifier {
  _StubUpdateStatusNotifier() : super(const UpToDate());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubDownloadNotifier extends StateNotifier<DownloadState>
    implements DownloadNotifier {
  _StubDownloadNotifier() : super(const DownloadState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A page on the shell navigator with its own Scaffold, as every edit form
/// has.
class _Page extends StatelessWidget {
  const _Page();

  static const bodyKey = ValueKey('pageBody');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Page')),
    body: const SizedBox.expand(key: bodyKey),
  );
}

Future<void> _pumpShell(
  WidgetTester tester,
  Widget page, {
  double keyboard = 0,
  FakeViewPadding padding = FakeViewPadding.zero,
  bool demo = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _screen;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.view.padding = padding;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => page),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        updateServiceProvider.overrideWith((ref) async => null),
        updateStatusProvider.overrideWith((ref) => _StubUpdateStatusNotifier()),
        downloadNotifierProvider.overrideWith((ref) => _StubDownloadNotifier()),
        settingsProvider.overrideWith((ref) => _StubSettingsNotifier()),
        demoModeActiveProvider.overrideWithValue(demo),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MediaQueryData _pageQuery(WidgetTester tester) =>
    MediaQuery.of(tester.element(find.byType(_Page)));

void main() {
  group('a shell page and the keyboard (#3784)', () {
    testWidgets('the keyboard takes its height off the page only once', (
      tester,
    ) async {
      await _pumpShell(tester, const _Page(), keyboard: _keyboard);

      expect(
        tester.getRect(find.byKey(_Page.bodyKey)).bottom,
        _screen.height - _keyboard,
      );
      expect(_pageQuery(tester).viewInsets.bottom, 0);
    });

    testWidgets('so does a page that hides the shell chrome', (tester) async {
      await _pumpShell(tester, const _Page(), keyboard: _keyboard);
      ShellChromeScope.maybeOf(
        tester.element(find.byType(_Page)),
      )!.requestHidden(tester);
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byKey(_Page.bodyKey)).bottom,
        _screen.height - _keyboard,
      );
      expect(_pageQuery(tester).viewInsets.bottom, 0);
    });

    testWidgets('so does a page below the demo strip', (tester) async {
      await _pumpShell(tester, const _Page(), keyboard: _keyboard, demo: true);

      expect(
        tester.getRect(find.byKey(_Page.bodyKey)).bottom,
        _screen.height - _keyboard,
      );
    });

    testWidgets('the formatting bar of long notes stays on screen', (
      tester,
    ) async {
      final notes = TextEditingController(
        text: List.generate(12, (i) => 'Line $i of the notes').join('\n'),
      );
      addTearDown(notes.dispose);
      await _pumpShell(
        tester,
        EditFormScaffold(
          title: 'Edit Dive',
          embedded: false,
          isSaving: false,
          hasUnsavedChanges: false,
          onSave: () {},
          child: ResponsiveFormColumns(
            children: [
              const SizedBox(height: 900),
              FormSection(
                label: 'Experience',
                expanded: true,
                onToggle: null,
                children: [
                  FormRow.text(
                    label: 'Notes',
                    controller: notes,
                    maxLines: 5,
                    markdown: true,
                  ),
                  const SizedBox(height: 300),
                ],
              ),
            ],
          ),
        ),
      );

      await tester.ensureVisible(find.text('Notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();
      // The keyboard arrives after the field takes focus.
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      await tester.pumpAndSettle();

      final bar = tester.getRect(find.byTooltip('Bold'));
      final appBar = tester.getRect(find.byType(AppBar));
      expect(bar.top, greaterThanOrEqualTo(appBar.bottom));
      expect(bar.bottom, lessThanOrEqualTo(_screen.height - _keyboard));
    });
  });

  group('a shell page and the system padding', () {
    testWidgets('the bottom bar alone clears the home indicator', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        const _Page(),
        padding: const FakeViewPadding(bottom: 34),
      );

      expect(_pageQuery(tester).padding.bottom, 0);
    });

    testWidgets('below the demo strip the status bar is cleared once (#3708)', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        const _Page(),
        padding: const FakeViewPadding(top: 47),
        demo: true,
      );

      expect(_pageQuery(tester).padding.top, 0);
    });
  });
}
