import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_multi_select_field.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';

import '../../../../helpers/test_app.dart';

class _MockCertListNotifier
    extends StateNotifier<AsyncValue<List<Certification>>>
    implements CertificationListNotifier {
  _MockCertListNotifier(List<Certification> certs)
    : super(AsyncValue.data(certs));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _now = DateTime(2026, 8, 24);

final _nitrox = Certification(
  id: 'nx',
  name: 'Nitrox',
  agency: 'padi',
  createdAt: _now,
  updatedAt: _now,
);

/// A certification created from a course's certification picker is chosen
/// in its place (#4809).
void main() {
  /// The new-certification page, standing in for the real one: pops
  /// `new-cert` on Create, nothing on Cancel.
  final newCertificationRoute = GoRoute(
    path: '/certifications/new',
    builder: (context, _) => Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () => context.pop('new-cert'),
            child: const Text('Create stub'),
          ),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel stub'),
          ),
        ],
      ),
    ),
  );

  Future<List<List<String>>> pumpField(
    WidgetTester tester, {
    required List<Certification> certs,
    required List<String> selected,
  }) async {
    final changes = <List<String>>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CertificationMultiSelectField(
                courseId: 'this-course',
                selectedCertificationIds: selected,
                onChanged: (ids) => setState(() {
                  selected = ids;
                  changes.add(ids);
                }),
              ),
            ),
          ),
        ),
        newCertificationRoute,
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          certificationListNotifierProvider.overrideWith(
            (ref) => _MockCertListNotifier(certs),
          ),
          allCoursesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return changes;
  }

  testWidgets('a certification created from the sheet is chosen with the '
      'others', (tester) async {
    final changes = await pumpField(tester, certs: [_nitrox], selected: ['nx']);
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New Cert'));
    await tester.pumpAndSettle();
    expect(find.text('Create stub'), findsOneWidget);

    await tester.tap(find.text('Create stub'));
    await tester.pumpAndSettle();
    expect(changes.last, ['nx', 'new-cert']);
  });

  testWidgets('one created from the empty sheet is chosen too', (tester) async {
    final changes = await pumpField(tester, certs: const [], selected: []);
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Certification'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create stub'));
    await tester.pumpAndSettle();
    expect(changes.last, ['new-cert']);
  });

  testWidgets('a cancelled new certification chooses nothing', (tester) async {
    final changes = await pumpField(tester, certs: [_nitrox], selected: ['nx']);
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New Cert'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel stub'));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
  });
}
