import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/presentation/widgets/wizard_message.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../support/clipboard_recorder.dart';

const _error =
    'Nothing was imported: the dates in 20 rows could not be read.\n'
    'Rows 2, 3, 4, 5, 6 and 15 more\n'
    'Check that the date and time columns are mapped on this step, and that '
    'they hold dates.';

Future<void> _pump(WidgetTester tester, WizardMessage message) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Column(children: [message])),
    ),
  );
}

Finder get _copyButton => find.byTooltip('Copy');

void main() {
  // A diver reporting a failed import had to screenshot the message, because
  // it could be neither selected nor copied (#3629).
  group('an error', () {
    testWidgets('can be selected', (tester) async {
      await _pump(
        tester,
        const WizardMessage(
          message: _error,
          icon: Icons.error_outline,
          isError: true,
        ),
      );

      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(text.data, _error);
    });

    testWidgets('the copy button copies the whole message and confirms', (
      tester,
    ) async {
      final calls = recordClipboardCalls();
      await _pump(
        tester,
        const WizardMessage(
          message: _error,
          icon: Icons.error_outline,
          isError: true,
        ),
      );

      await tester.tap(_copyButton);
      await tester.pump();

      expect(copiedText(calls), _error);
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });

    testWidgets('a clipboard that refuses says so', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              throw PlatformException(code: 'unavailable');
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _pump(
        tester,
        const WizardMessage(
          message: _error,
          icon: Icons.error_outline,
          isError: true,
        ),
      );

      await tester.tap(_copyButton);
      await tester.pump();

      expect(find.text('Copied to clipboard'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  testWidgets('a warning can be selected but has no copy button', (
    tester,
  ) async {
    await _pump(
      tester,
      const WizardMessage(
        message: 'Duplicate check failed.',
        icon: Icons.warning_amber_outlined,
        isError: false,
      ),
    );

    expect(find.byType(SelectableText), findsOneWidget);
    expect(_copyButton, findsNothing);
  });
}
