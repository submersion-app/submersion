import 'package:flutter_test/flutter_test.dart';

import 'provider_family_scanner.dart';

/// Unit tests for the scanner behind the lib/ checks in
/// `dive_provider_disposal_test.dart`, on synthetic source so the shapes it
/// recognises stay pinned as the codebase moves.
void main() {
  Map<String, ProviderFamilyDeclaration> scan(String source) => {
    for (final family in scanProviderFamilies('fixture.dart', source))
      family.name: family,
  };

  test('reads a keep-forever family and what it watches', () {
    final families = scan('''
final aProvider = FutureProvider.family<int, String>((ref, id) async {
  final dive = await ref.watch(diveProvider(id).future);
  ref.listen(otherProvider(id), (_, _) {});
  return 0;
});
''');

    final family = families['aProvider']!;
    expect(family.isAutoDispose, isFalse);
    expect(family.retains, isFalse);
    expect(family.watched, {'diveProvider', 'otherProvider'});
    expect(family.line, 1);
  });

  test('reads an autoDispose family that retains its entry', () {
    final families = scan('''
final bProvider = FutureProvider.autoDispose
    .family<int, String>((ref, id) async {
      retainDiveData(ref);
      return 0;
    });
''');

    expect(families['bProvider']!.isAutoDispose, isTrue);
    expect(families['bProvider']!.retains, isTrue);
  });

  test('counts isAutoDispose: true as autoDispose', () {
    final families = scan('''
final cProvider = Provider.family<int, String>(
  (ref, id) => 0,
  isAutoDispose: true,
);
''');

    expect(families['cProvider']!.isAutoDispose, isTrue);
  });

  test('names a watched provider through select and multi-line calls', () {
    final families = scan('''
final dProvider = FutureProvider.family<int?, String>((ref, id) async {
  final first = await ref.watch(
    routesProvider(
      id,
    ).selectAsync((routes) => routes.length),
  );
  return ref.watch(countProvider(id).select((c) => c + first));
});
''');

    expect(families['dProvider']!.watched, {'routesProvider', 'countProvider'});
  });

  test('names a provider watched through an import prefix', () {
    final families = scan('''
final fProvider = FutureProvider.family<int, String>((ref, id) async {
  await ref.watch(analysis.profileAnalysisProvider(id).future);
  return 0;
});
''');

    expect(families['fProvider']!.watched, {'profileAnalysisProvider'});
  });

  test('ignores non-family providers and other variables', () {
    final families = scan('''
final plainProvider = Provider<int>((ref) => ref.watch(diveProvider('a')));
final notAProvider = compute.family(1);
const limit = 5;
''');

    expect(families, isEmpty);
  });

  test('does not count a watch on something other than ref', () {
    final families = scan('''
final eProvider = Provider.family<int, String>((ref, id) {
  other.watch(diveProvider(id));
  return 0;
});
''');

    expect(families['eProvider']!.watched, isEmpty);
  });
}
