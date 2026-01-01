import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/settings/presentation/providers/settings_providers.dart';
import 'features/settings/presentation/providers/sync_providers.dart';

class SubmersionApp extends ConsumerWidget {
  const SubmersionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Restore the last used cloud sync provider on app startup
    ref.watch(restoreLastProviderProvider);

    return MaterialApp.router(
      title: 'Submersion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
