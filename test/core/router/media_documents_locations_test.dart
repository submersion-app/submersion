import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/router/media_documents_locations.dart';
import 'package:submersion/shared/widgets/section_tabs/section_tab.dart';

void main() {
  test('sectionTabForPath matches the Media list roots only', () {
    MediaDocumentsTab? tabFor(String path) =>
        sectionTabForPath(MediaDocumentsTab.values, path);
    expect(tabFor('/media'), MediaDocumentsTab.media);
    expect(tabFor('/documents'), MediaDocumentsTab.documents);
    expect(tabFor('/documents/abc'), isNull);
    expect(tabFor('/documents/new'), isNull);
  });

  test('no code pushes a Media list root except Home', () {
    // Both list roots build their page under kMediaDocumentsHostPageKey.
    // Pushing a root while a Media host is already on the stack would give
    // the Navigator two pages with one key, which asserts in debug builds.
    // Home's status lights and its media panel are safe: Home never sits
    // above a Media host, and a push keeps Back returning to Home.
    // By path (push, pushReplacement, pushOrReturnTo) or by route name
    // (pushNamed, pushReplacementNamed), with or without more arguments.
    final rootPush = RegExp(
      r'''(?:(?:push|pushReplacement|pushOrReturnTo)(?:<[^>]*>)?\(\s*'/(?:media|documents)(?:\?[^']*)?'\s*[,)])'''
      r'''|(?:(?:pushNamed|pushReplacementNamed)(?:<[^>]*>)?\(\s*'(?:media|documents)'\s*[,)])''',
    );
    final allowed = [
      p.join(
        'lib',
        'features',
        'dashboard',
        'presentation',
        'panels',
        'conditional_panels.dart',
      ),
      p.join(
        'lib',
        'features',
        'dashboard',
        'presentation',
        'widgets',
        'home_status_lights.dart',
      ),
    ];
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (rootPush.hasMatch(entity.readAsStringSync())) {
        hits.add(p.normalize(entity.path));
      }
    }
    hits.sort();
    expect(
      hits,
      allowed,
      reason:
          'A push of a Media list root can stack a second page with '
          'kMediaDocumentsHostPageKey. Use go() or goInPlace() instead.',
    );
  });
}
