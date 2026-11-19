import 'package:flutter/material.dart';

import 'package:submersion/core/theme/app_theme_registry.dart';

/// Pushes [page] over a plain first route reading "first route", so a page
/// under test can pop (after a delete or a split, say) and a test can see
/// it went back.
class PushedPageLauncher extends StatefulWidget {
  const PushedPageLauncher({super.key, required this.page, this.theme});

  final Widget page;

  /// The app's own theme in this brightness, for screenshots; the test
  /// app's default when null.
  final Brightness? theme;

  @override
  State<PushedPageLauncher> createState() => _PushedPageLauncherState();
}

class _PushedPageLauncherState extends State<PushedPageLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final theme = widget.theme;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => theme == null
              ? widget.page
              : Theme(
                  data: AppThemeRegistry.resolveTheme(
                    AppThemeRegistry.presets.first,
                    theme,
                  ),
                  child: widget.page,
                ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Text('first route');
}
