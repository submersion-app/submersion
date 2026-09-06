import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/auto_update/domain/entities/build_train.dart';
import 'package:submersion/features/auto_update/presentation/widgets/beta_build_notice.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  group('shouldShowBetaBuildNotice', () {
    test('shows on a beta build the user has not been warned about', () {
      // The #1568 case: a direct download from beta-builds, so the channel
      // picker never ran and the warning was never read.
      expect(
        shouldShowBetaBuildNotice(train: BuildTrain.beta, alreadySeen: false),
        isTrue,
      );
    });

    test('stays silent on a stable build', () {
      expect(
        shouldShowBetaBuildNotice(train: BuildTrain.stable, alreadySeen: false),
        isFalse,
      );
    });

    test('stays silent once the warning has been read', () {
      // Set either by dismissing this notice, or by confirming the in-app
      // switch to beta, which shows the same body text.
      expect(
        shouldShowBetaBuildNotice(train: BuildTrain.beta, alreadySeen: true),
        isFalse,
      );
    });

    test('never fires on a stable build, warned or not', () {
      expect(
        shouldShowBetaBuildNotice(train: BuildTrain.stable, alreadySeen: true),
        isFalse,
      );
    });
  });

  group('showBetaBuildNotice', () {
    testWidgets('carries the channel picker warning verbatim', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return TextButton(
                onPressed: () => showBetaBuildNotice(context),
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.settings_updates_betaBuildNoticeTitle), findsOne);
      // The database warning is the whole point of the dialog: the same string
      // the picker shows before switching to beta, so there is one text to
      // keep accurate rather than two that can drift.
      expect(
        find.textContaining(l10n.settings_updates_betaDialogBody),
        findsOne,
      );
    });

    testWidgets('closes on acknowledgement', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBetaBuildNotice(context),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOne);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
