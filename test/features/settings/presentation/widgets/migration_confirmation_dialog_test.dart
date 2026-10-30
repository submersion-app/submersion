import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/full_themes/submersion_theme.dart';
import 'package:submersion/features/settings/presentation/widgets/migration_confirmation_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/contrast_ratio.dart';

void main() {
  // The arrow between the two paths was fixed Colors.grey, about 2.3:1 on
  // the light dialog surface.
  for (final theme in [submersionLight, submersionDark]) {
    testWidgets('the path arrow reads in ${theme.brightness.name} mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: MigrationConfirmationDialog(
              fromPath: '/from',
              toPath: '/to',
              isMovingToCustom: true,
            ),
          ),
        ),
      );

      final arrow = find.byIcon(Icons.arrow_downward);
      final color = tester.widget<Icon>(arrow).color!;
      final dialog =
          theme.dialogTheme.backgroundColor ??
          theme.colorScheme.surfaceContainerHigh;
      expect(contrastRatio(color, dialog), greaterThanOrEqualTo(3.0));
    });
  }
}
