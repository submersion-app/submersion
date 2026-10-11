import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_export_actions.dart';

import '../../../../helpers/test_app.dart';

/// What reached the injected share or save function.
class _Delivery {
  _Delivery(
    this.bytes,
    this.fileName,
    this.mimeType, {
    this.origin,
    this.title,
  });

  final List<int> bytes;
  final String fileName;
  final String mimeType;
  final Rect? origin;
  final String? title;
}

void main() {
  const anchor = Rect.fromLTWH(10, 20, 30, 40);
  const file = (
    bytes: <int>[1, 2, 3],
    fileName: 'Reef_slate.pdf',
    mimeType: 'application/pdf',
  );

  late List<_Delivery> shared;
  late List<_Delivery> saved;
  late int builds;
  late String? saveResult;
  Object? buildError;
  Object? deliveryError;

  setUp(() {
    shared = [];
    saved = [];
    builds = 0;
    saveResult = '/exports/Reef_slate.pdf';
    buildError = null;
    deliveryError = null;
  });

  Widget harness({PlanExportFile? built = file}) => testApp(
    child: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => deliverPlanExport(
          context,
          title: 'Export slate (PDF)',
          savedMessage: 'Slate saved',
          shareAnchor: anchor,
          build: () async {
            builds++;
            if (buildError != null) throw buildError!;
            return built;
          },
          share: (bytes, fileName, mimeType, origin) async {
            if (deliveryError != null) throw deliveryError!;
            shared.add(_Delivery(bytes, fileName, mimeType, origin: origin));
          },
          save: (bytes, fileName, mimeType, dialogTitle) async {
            if (deliveryError != null) throw deliveryError!;
            saved.add(_Delivery(bytes, fileName, mimeType, title: dialogTitle));
            return saveResult;
          },
        ),
        child: const Text('export'),
      ),
    ),
  );

  Future<void> openSheet(
    WidgetTester tester, {
    PlanExportFile? built = file,
  }) async {
    await tester.pumpWidget(harness(built: built));
    await tester.tap(find.text('export'));
    await tester.pumpAndSettle();
  }

  testWidgets('asks where the export goes before building it', (tester) async {
    await openSheet(tester);

    expect(find.text('Export slate (PDF)'), findsOneWidget);
    expect(find.text('Save to File'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(builds, 0);
  });

  testWidgets('a dismissed sheet builds and delivers nothing', (tester) async {
    await openSheet(tester);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(builds, 0);
    expect(shared, isEmpty);
    expect(saved, isEmpty);
  });

  testWidgets('Save to File hands the file to the save dialog and confirms', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();

    final delivery = saved.single;
    expect(delivery.bytes, [1, 2, 3]);
    expect(delivery.fileName, 'Reef_slate.pdf');
    expect(delivery.mimeType, 'application/pdf');
    expect(delivery.title, 'Export slate (PDF)');
    expect(shared, isEmpty);
    expect(find.text('Slate saved'), findsOneWidget);
  });

  testWidgets('a cancelled save dialog says nothing', (tester) async {
    saveResult = null;
    await openSheet(tester);

    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(find.text('Slate saved'), findsNothing);
  });

  testWidgets('Share hands the file to the share sheet at the anchor', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    final delivery = shared.single;
    expect(delivery.bytes, [1, 2, 3]);
    expect(delivery.fileName, 'Reef_slate.pdf');
    expect(delivery.mimeType, 'application/pdf');
    expect(delivery.origin, anchor);
    expect(saved, isEmpty);
    expect(find.text('Slate saved'), findsNothing);
  });

  testWidgets('nothing to export delivers nothing', (tester) async {
    await openSheet(tester, built: null);

    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();

    expect(builds, 1);
    expect(saved, isEmpty);
    expect(shared, isEmpty);
  });

  testWidgets('a failed build says the export failed', (tester) async {
    buildError = StateError('no outcome');
    await openSheet(tester);

    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();

    expect(saved, isEmpty);
    expect(find.text('Export failed: Bad state: no outcome'), findsOneWidget);
  });

  testWidgets('a failed save says the export failed', (tester) async {
    deliveryError = const FileSystemException('Access is denied');
    await openSheet(tester);

    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Export failed: '), findsOneWidget);
    expect(find.textContaining('Access is denied'), findsOneWidget);
    expect(find.text('Slate saved'), findsNothing);
  });

  testWidgets('a failed share says the export failed', (tester) async {
    deliveryError = StateError('no share target');
    await openSheet(tester);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(
      find.text('Export failed: Bad state: no share target'),
      findsOneWidget,
    );
  });
}
