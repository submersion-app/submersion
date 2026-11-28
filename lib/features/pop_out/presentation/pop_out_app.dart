import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/app.dart'
    show resolveAppLocale, resolveLocaleSetting;
import 'package:submersion/core/presentation/localizations/week_start_material_localizations.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/features/pop_out/presentation/pop_out_profile_view.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_client.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The root of a profile pop-out window (issue #5078): the main window's
/// theme, language and display zoom around [PopOutProfileView].
class PopOutApp extends ConsumerWidget {
  const PopOutApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listened for the window's whole life, so the client keeps hearing the
    // main window.
    ref.listen(popOutClientNotifierProvider, (_, _) {});
    final themeMode = ref.watch(themeModeProvider);
    final themePreset = ref.watch(themePresetProvider);
    final localeSetting = ref.watch(localeProvider);
    final firstWeekday = ref.watch(firstWeekdayProvider);
    return MaterialApp(
      title: 'Submersion',
      debugShowCheckedModeBanner: false,
      theme: AppThemeRegistry.resolveTheme(themePreset, Brightness.light),
      darkTheme: AppThemeRegistry.resolveTheme(themePreset, Brightness.dark),
      themeMode: themeMode,
      locale: resolveLocaleSetting(localeSetting),
      localeListResolutionCallback: (preferredLocales, supportedLocales) =>
          resolveAppLocale(preferredLocales, supportedLocales),
      localizationsDelegates: [
        WeekStartMaterialLocalizationsDelegate(firstWeekday),
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
        return Consumer(
          builder: (context, ref, _) => DisplayZoomScope(
            zoom: ref.watch(displayZoomNotifierProvider),
            child: child!,
          ),
        );
      },
      home: const PopOutProfileView(),
    );
  }
}

/// Shown instead when the window could not reach the main window's
/// database; there is nothing it could show.
class PopOutConnectFailedApp extends StatelessWidget {
  const PopOutConnectFailedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                AppLocalizations.of(context).popOut_connectFailed,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
