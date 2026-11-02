import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/detail_row/copyable_detail_row.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';
import 'package:submersion/shared/widgets/detail_row/render_detail_row.dart';

import '../../../support/clipboard_recorder.dart';

const _cardNumber = '2204198700453318762-AOW';

/// Pumps [child] at [width] logical pixels, pinned to the top start corner.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 300,
  TextDirection textDirection = TextDirection.ltr,
  TargetPlatform platform = TargetPlatform.android,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Directionality(
        textDirection: textDirection,
        child: Scaffold(
          body: Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

Widget _row({
  String label = 'Card',
  String value = 'A7X-20419',
  bool copyable = true,
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(vertical: 8),
}) => DetailRow.text(
  label: label,
  value: value,
  copyable: copyable,
  padding: padding,
);

Finder get _copyButton => find.byTooltip('Copy');

void main() {
  group('copying', () {
    testWidgets('a plain row has no button and ignores a long press', (
      tester,
    ) async {
      final calls = recordClipboardCalls();
      await _pump(tester, _row(copyable: false));

      expect(_copyButton, findsNothing);
      await tester.longPress(find.text('A7X-20419'));
      await tester.pump();

      expect(copiedText(calls), isNull);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('the button copies the value and confirms', (tester) async {
      final calls = recordClipboardCalls();
      await _pump(tester, _row(value: _cardNumber));

      await tester.tap(_copyButton);
      await tester.pump();

      expect(copiedText(calls), _cardNumber);
      expect(find.text('Copied to clipboard'), findsOneWidget);
      expect(
        calls.where(
          (c) =>
              c.method == 'HapticFeedback.vibrate' &&
              c.arguments == 'HapticFeedbackType.mediumImpact',
        ),
        hasLength(1),
      );
    });

    for (final target in ['Card', 'A7X-20419']) {
      testWidgets('a long press on "$target" copies the value', (tester) async {
        final calls = recordClipboardCalls();
        await _pump(tester, _row());

        await tester.longPress(find.text(target));
        await tester.pump();

        expect(copiedText(calls), 'A7X-20419');
        expect(find.text('Copied to clipboard'), findsOneWidget);
      });
    }

    testWidgets('a long press gives one haptic, not the platform one as well', (
      tester,
    ) async {
      final calls = recordClipboardCalls();
      await _pump(tester, _row());

      await tester.longPress(find.text('A7X-20419'));
      await tester.pump();

      expect(
        calls.where((c) => c.method == 'HapticFeedback.vibrate'),
        hasLength(1),
      );
    });

    testWidgets('a tap on the row copies nothing', (tester) async {
      final calls = recordClipboardCalls();
      await _pump(tester, _row());

      await tester.tap(find.text('A7X-20419'));
      await tester.pump();

      expect(copiedText(calls), isNull);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a long press on the button copies too', (tester) async {
      final calls = recordClipboardCalls();
      await _pump(tester, _row());

      await tester.longPress(_copyButton);
      await tester.pump();

      expect(copiedText(calls), 'A7X-20419');
    });

    testWidgets('a long press on the button gives one haptic', (tester) async {
      final calls = recordClipboardCalls();
      await _pump(tester, _row());

      await tester.longPress(_copyButton);
      await tester.pump();

      expect(
        calls.where((c) => c.method == 'HapticFeedback.vibrate'),
        hasLength(1),
      );
    });

    for (final blank in ['', '   ']) {
      testWidgets('a blank value "$blank" offers nothing to copy', (
        tester,
      ) async {
        final calls = recordClipboardCalls();
        await _pump(tester, _row(value: blank));

        expect(_copyButton, findsNothing);
        await tester.longPress(find.text('Card'));
        await tester.pump();

        expect(copiedText(calls), isNull);
      });
    }

    testWidgets('a clipboard failure says so and gives no success haptic', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'unavailable');
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _pump(tester, _row());

      await tester.tap(_copyButton);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Copied to clipboard'), findsNothing);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(
        calls.where(
          (c) =>
              c.method == 'HapticFeedback.vibrate' &&
              c.arguments == 'HapticFeedbackType.mediumImpact',
        ),
        isEmpty,
      );
    });

    testWidgets('copying leaves another message on screen alone', (
      tester,
    ) async {
      recordClipboardCalls();
      await _pump(tester, _row());
      final context = tester.element(find.byType(DetailRow));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item deleted')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(_copyButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Item deleted'), findsOneWidget);
      expect(find.text('Copied to clipboard'), findsNothing);
    });

    testWidgets('on desktop the row does not pose as a button', (tester) async {
      await _pump(tester, _row(), platform: TargetPlatform.macOS);

      final ink = tester.widget<InkWell>(
        find.ancestor(
          of: find.byType(DetailRowLayout),
          matching: find.byType(InkWell),
        ),
      );
      expect(ink.mouseCursor, SystemMouseCursors.basic);
      expect(ink.canRequestFocus, isFalse);
      expect(ink.hoverColor, Colors.transparent);
    });

    testWidgets('a second copy replaces the message rather than queueing', (
      tester,
    ) async {
      recordClipboardCalls();
      await _pump(tester, _row());

      Future<void> elapse(Duration time) async {
        const frame = Duration(milliseconds: 50);
        for (var t = Duration.zero; t < time; t += frame) {
          await tester.pump(frame);
        }
      }

      await tester.tap(_copyButton);
      await elapse(const Duration(milliseconds: 400));
      await tester.tap(_copyButton);
      await elapse(const Duration(milliseconds: 800));
      expect(find.text('Copied to clipboard'), findsOneWidget);

      // The replacement has run its two seconds and left. A queued message
      // would still be on screen, having waited out the first one's.
      await elapse(const Duration(milliseconds: 2500));
      expect(find.text('Copied to clipboard'), findsNothing);
    });
  });

  group('layout', () {
    for (final padding in const [4.0, 6.0, 8.0]) {
      testWidgets('copying adds no height at padding $padding', (tester) async {
        final inset = EdgeInsets.symmetric(vertical: padding);

        await _pump(tester, _row(copyable: false, padding: inset));
        final plain = tester.getSize(find.byType(DetailRow)).height;

        await _pump(tester, _row(padding: inset));
        expect(tester.getSize(find.byType(DetailRow)).height, plain);
      });
    }

    testWidgets('a copyable value stays on the shared column at the 40% cap', (
      tester,
    ) async {
      // The cap measures the whole row, so a button taken out of the row's
      // width would pull this value out of line with its neighbour.
      await _pump(
        tester,
        DetailRowGroup(
          child: Column(
            children: [
              _row(label: 'A label wider than the cap', value: 'copy me'),
              _row(
                label: 'A label wider than the cap',
                value: 'not me',
                copyable: false,
              ),
            ],
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.text('copy me')).dx,
        tester.getTopLeft(find.text('not me')).dx,
      );
    });

    testWidgets('a wrapped value stops short of the button', (tester) async {
      await _pump(tester, _row(value: _cardNumber));

      final value = find.text(_cardNumber);
      expect(tester.getSize(value).height, greaterThan(20));
      expect(
        tester.getTopRight(value).dx,
        lessThanOrEqualTo(tester.getTopLeft(_copyButton).dx),
      );
    });

    testWidgets('the button holds the far edge', (tester) async {
      await _pump(tester, _row());

      expect(
        tester.getTopRight(_copyButton).dx,
        tester.getTopRight(find.byType(DetailRow)).dx,
      );
    });

    testWidgets('the button holds the far edge in RTL', (tester) async {
      await _pump(tester, _row(), textDirection: TextDirection.rtl);

      expect(
        tester.getTopLeft(_copyButton).dx,
        tester.getTopLeft(find.byType(DetailRow)).dx,
      );
      expect(
        tester.getTopLeft(find.text('A7X-20419')).dx,
        greaterThanOrEqualTo(tester.getTopRight(_copyButton).dx),
      );
    });

    testWidgets('a wrapped row keeps the button on its first line', (
      tester,
    ) async {
      await _pump(tester, _row(value: _cardNumber));

      expect(
        tester.getCenter(find.byIcon(Icons.content_copy)).dy,
        closeTo(tester.getCenter(find.text('Card')).dy, 0.01),
      );
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
      testWidgets('the tap area spans the first line on ${platform.name}', (
        tester,
      ) async {
        await _pump(tester, _row(), platform: platform);

        expect(
          tester.getSize(find.byType(IconButton)),
          const Size(CopyableDetailRow.buttonWidth, 36),
        );
      });
    }
  });

  testWidgets('a screen reader hears the row, then a Copy button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final calls = recordClipboardCalls();
    await _pump(tester, _row());

    final row = find.bySemanticsLabel('Card: A7X-20419');
    expect(row, findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Card$')), findsNothing);
    expect(
      tester.getSemantics(row),
      matchesSemantics(
        label: 'Card: A7X-20419',
        hasLongPressAction: true,
        onLongPressHint: 'Copy',
      ),
    );
    expect(
      tester.getSemantics(_copyButton),
      matchesSemantics(
        tooltip: 'Copy',
        isButton: true,
        hasTapAction: true,
        hasLongPressAction: true,
        hasFocusAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
      ),
    );

    tester.semantics.longPress(find.semantics.byLabel('Card: A7X-20419'));
    await tester.pump();
    expect(copiedText(calls), 'A7X-20419');

    // Disposed in the body: the binding checks for a live handle before
    // tear-downs run.
    semantics.dispose();
  });

  testWidgets('an unbounded row still lays out', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: UnconstrainedBox(child: IntrinsicWidth(child: _row())),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(_copyButton, findsOneWidget);
  });
}
