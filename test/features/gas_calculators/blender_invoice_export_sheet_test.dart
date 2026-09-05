import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_invoice_export_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Captures the [Future] a test's `showModalBottomSheet` call returns.
///
/// A plain local variable can't do this: an `async` helper that `return`s a
/// `Future<T>` matching its own declared `Future<T>` return type gets that
/// inner future auto-awaited by Dart before the helper itself completes
/// (the "returning a future from an async function" flattening pitfall) -
/// which would deadlock here, since nothing pops the sheet until after the
/// helper returns.
class _PickerResult {
  Future<(BlenderInvoiceExportFormat, Rect?)?>? future;
}

/// The actual export - and, in particular, opening the OS share sheet - now
/// runs in [BlenderInvoiceCard] only after this sheet has fully closed (see
/// `blender_invoice_test.dart`, group "export"). This file only checks what
/// the sheet itself is responsible for: offering the three formats and
/// popping with the diver's choice.
void main() {
  Future<void> pumpAndOpen(WidgetTester tester, _PickerResult result) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  result.future =
                      showModalBottomSheet<(BlenderInvoiceExportFormat, Rect?)>(
                        context: context,
                        builder: (context) => const BlenderInvoiceExportSheet(),
                      );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers PDF, image and Excel as the three export options', (
    tester,
  ) async {
    await pumpAndOpen(tester, _PickerResult());

    expect(find.byKey(const Key('blender-export-pdf')), findsOneWidget);
    expect(find.byKey(const Key('blender-export-image')), findsOneWidget);
    expect(find.byKey(const Key('blender-export-excel')), findsOneWidget);
  });

  testWidgets('tapping PDF pops the chosen format and closes the sheet', (
    tester,
  ) async {
    final result = _PickerResult();
    await pumpAndOpen(tester, result);

    await tester.tap(find.byKey(const Key('blender-export-pdf')));
    await tester.pumpAndSettle();

    final choice = await result.future;
    expect(choice?.$1, BlenderInvoiceExportFormat.pdf);
    expect(find.byType(BlenderInvoiceExportSheet), findsNothing);
  });

  testWidgets('tapping Image pops the image format', (tester) async {
    final result = _PickerResult();
    await pumpAndOpen(tester, result);

    await tester.tap(find.byKey(const Key('blender-export-image')));
    await tester.pumpAndSettle();

    final choice = await result.future;
    expect(choice?.$1, BlenderInvoiceExportFormat.image);
  });

  testWidgets('tapping Excel pops the excel format', (tester) async {
    final result = _PickerResult();
    await pumpAndOpen(tester, result);

    await tester.tap(find.byKey(const Key('blender-export-excel')));
    await tester.pumpAndSettle();

    final choice = await result.future;
    expect(choice?.$1, BlenderInvoiceExportFormat.excel);
  });
}
