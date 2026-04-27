import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/widgets/files_tab.dart';

void main() {
  testWidgets('renders Pick files action', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: FilesTab())),
      ),
    );
    expect(find.textContaining('Pick files'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows empty-state hint when no files picked', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: FilesTab())),
      ),
    );
    expect(find.textContaining('Pick files or'), findsOneWidget);
  });
}
