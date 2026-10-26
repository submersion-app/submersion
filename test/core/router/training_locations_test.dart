import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/router/training_locations.dart';
import 'package:submersion/shared/widgets/section_tabs/section_tab.dart';

/// Records each State it creates, so a test can tell an in-place update of
/// the host page from a rebuild that would lose the tabs' state.
class _Probe extends StatefulWidget {
  const _Probe({required this.tab, required this.created});

  final TrainingTab tab;
  final List<TrainingTab> created;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.created.add(widget.tab);
  }

  @override
  Widget build(BuildContext context) => Text('host ${widget.tab.name}');
}

/// Shell-shaped like the real app: the list roots live inside one ShellRoute.
GoRouter _router(List<TrainingTab> created, {String initial = '/home'}) {
  return GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const Text('home')),
          GoRoute(
            path: '/certifications',
            pageBuilder: (_, _) => trainingHostPage(
              _Probe(tab: TrainingTab.certifications, created: created),
            ),
            routes: [
              GoRoute(path: ':id', builder: (_, _) => const Text('detail')),
            ],
          ),
          GoRoute(
            path: '/courses',
            pageBuilder: (_, _) => trainingHostPage(
              _Probe(tab: TrainingTab.courses, created: created),
            ),
          ),
        ],
      ),
    ],
  );
}

Future<GoRouter> _pump(
  WidgetTester tester,
  List<TrainingTab> created, {
  String initial = '/home',
}) async {
  final router = _router(created, initial: initial);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('go between tabs keeps the host State', (tester) async {
    final created = <TrainingTab>[];
    final router = await _pump(tester, created, initial: '/certifications');

    router.go('/courses');
    await tester.pumpAndSettle();

    expect(find.text('host courses'), findsOneWidget);
    expect(created, [TrainingTab.certifications]);
  });

  testWidgets('replace between tabs on a pushed host keeps the State', (
    tester,
  ) async {
    final created = <TrainingTab>[];
    final router = await _pump(tester, created);

    router.push('/certifications');
    await tester.pumpAndSettle();
    router.replace('/courses');
    await tester.pumpAndSettle();

    expect(find.text('host courses'), findsOneWidget);
    expect(created, [TrainingTab.certifications]);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('pushing a detail and popping keeps the host State', (
    tester,
  ) async {
    final created = <TrainingTab>[];
    final router = await _pump(tester, created, initial: '/certifications');

    router.push('/certifications/x');
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('host certifications'), findsOneWidget);
    expect(created, [TrainingTab.certifications]);
  });

  testWidgets('pushing the other tab\'s detail over the host builds only '
      'the detail, never a second host', (tester) async {
    // A course page links to its certification with push('/certifications/
    // <id>'). go_router builds a pushed location as one page, its leaf, so
    // the Certifications list under it is not built a second time beside the
    // Courses host already on the stack.
    final created = <TrainingTab>[];
    final router = await _pump(tester, created, initial: '/courses');

    router.push('/certifications/x');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('detail'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('host courses'), findsOneWidget);
    expect(created, [TrainingTab.courses]);
  });

  test('sectionTabForPath matches list roots only', () {
    TrainingTab? tabFor(String path) =>
        sectionTabForPath(TrainingTab.values, path);
    expect(tabFor('/certifications'), TrainingTab.certifications);
    expect(tabFor('/courses'), TrainingTab.courses);
    expect(tabFor('/certifications/abc'), isNull);
    expect(tabFor('/training'), isNull);
  });

  test('no code pushes a Training list root except the Home attention chip', () {
    // Both list roots build their page under kTrainingHostPageKey. Pushing a
    // root while a Training host is already on the stack would give the
    // Navigator two pages with one key, which asserts in debug builds. The
    // Home chip is safe: Home never sits above a Training host.
    // By path (push, pushReplacement, pushOrReturnTo) or by route name
    // (pushNamed, pushReplacementNamed), with or without more arguments.
    final rootPush = RegExp(
      r'''(?:(?:push|pushReplacement|pushOrReturnTo)(?:<[^>]*>)?\(\s*'/(?:certifications|courses)(?:\?[^']*)?'\s*[,)])'''
      r'''|(?:(?:pushNamed|pushReplacementNamed)(?:<[^>]*>)?\(\s*'(?:certifications|courses)'\s*[,)])''',
    );
    final allowed = p.join(
      'lib',
      'features',
      'certifications',
      'presentation',
      'certification_attention_navigation.dart',
    );
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (rootPush.hasMatch(entity.readAsStringSync())) {
        hits.add(p.normalize(entity.path));
      }
    }
    expect(
      hits,
      [allowed],
      reason:
          'A push of a Training list root can stack a second page with '
          'kTrainingHostPageKey. Use go() or goInPlace() instead.',
    );
  });
}
