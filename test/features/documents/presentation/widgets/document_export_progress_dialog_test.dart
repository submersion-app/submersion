import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/presentation/widgets/document_export_progress_dialog.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('shows progress and Cancel reaches the export', (t) async {
    final progress = ValueNotifier<DocumentExportProgress>((
      done: 3,
      total: 12,
    ));
    addTearDown(progress.dispose);
    var cancels = 0;
    await t.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: DocumentExportProgressDialog(
          progress: progress,
          onCancel: () => cancels++,
        ),
      ),
    );
    expect(find.text('File 3 of 12'), findsOneWidget);
    expect(
      t
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.25,
    );

    progress.value = (done: 6, total: 12);
    await t.pump();
    expect(find.text('File 6 of 12'), findsOneWidget);

    await t.tap(find.text('Cancel'));
    expect(cancels, 1);
  });
}
