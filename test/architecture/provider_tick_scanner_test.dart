import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'provider_tick_scanner.dart';

/// Unit tests for the scanner that backs
/// `test/architecture/provider_change_tick_test.dart`.
///
/// Uses synthetic source in a temp directory rather than the real `lib/` tree,
/// so the accept/reject shapes stay pinned even as the codebase moves.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('tick_scanner'));
  tearDown(() => temp.deleteSync(recursive: true));

  File write(String name, String source) =>
      File('${temp.path}/$name')..writeAsStringSync(source);

  const repositorySource = '''
class FooRepository {
  Stream<void> watchFooChanges() => const Stream.empty();
}

class BareRepository {
  Stream<void> watchChanges() => const Stream.empty();
}
''';

  ScanResult scan(String providerSource) {
    final repository = write('repo.dart', repositorySource);
    final providers = write('providers.dart', providerSource);
    return scanForTickViolations(
      repositoryFiles: [repository],
      providerFiles: [providers],
      relativize: (path) => path.split('/').last,
    );
  }

  test('collects tick names including the bare watchChanges form', () {
    final result = scan('final unrelatedProvider = Provider<int>((ref) => 1);');
    expect(result.tickNames, {'watchFooChanges', 'watchChanges'});
    expect(result.tickDeclarationCount, 2);
  });

  test('flags a provider that calls a repository method with no tick', () {
    final result = scan('''
final fooProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fooRepositoryProvider);
  return repository.getFoo();
});
''');
    expect(result.repositoryReadingProviders, 1);
    expect(result.violations, hasLength(1));
    expect(result.violations.single.provider, 'fooProvider');
    expect(result.violations.single.repositoryCall, 'repository.getFoo()');
  });

  test('accepts a provider that subscribes via invalidateSelfWhen', () {
    final result = scan('''
final fooProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fooRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchFooChanges());
  return repository.getFoo();
});
''');
    expect(result.violations, isEmpty);
  });

  test('accepts a raw listen subscription, the StateNotifier shape', () {
    final result = scan('''
final fooProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fooRepositoryProvider);
  final sub = repository.watchFooChanges().listen((_) {});
  ref.onDispose(sub.cancel);
  return repository.getFoo();
});
''');
    expect(result.violations, isEmpty);
  });

  test('accepts a tick reached through a same-file helper', () {
    final result = scan('''
void _subscribe(Ref ref) {
  ref.invalidateSelfWhen(ref.watch(fooRepositoryProvider).watchFooChanges());
}

final fooProvider = FutureProvider<int>((ref) async {
  _subscribe(ref);
  final repository = ref.watch(fooRepositoryProvider);
  return repository.getFoo();
});
''');
    expect(result.violations, isEmpty);
  });

  test('ignores a provider that only passes a repository as an argument', () {
    final result = scan('''
final exportServiceProvider = Provider<ExportService>((ref) {
  final repository = ref.watch(fooRepositoryProvider);
  return ExportService(repository);
});
''');
    expect(result.repositoryReadingProviders, 0);
    expect(result.violations, isEmpty);
  });

  test('flags a chained ref.watch(repo).method() call', () {
    // The repository is never bound to a local, so the call target is the
    // ref.watch expression itself rather than an identifier.
    final result = scan('''
final fooProvider = FutureProvider<int>((ref) async {
  return ref.watch(fooRepositoryProvider).getFoo();
});
''');
    expect(result.repositoryReadingProviders, 1);
    expect(result.violations, hasLength(1));
    expect(
      result.violations.single.repositoryCall,
      'ref.watch(fooRepositoryProvider).getFoo()',
    );
  });

  test('accepts a chained call when a tick is also subscribed', () {
    final result = scan('''
final fooProvider = FutureProvider<int>((ref) async {
  ref.invalidateSelfWhen(ref.watch(fooRepositoryProvider).watchFooChanges());
  return ref.watch(fooRepositoryProvider).getFoo();
});
''');
    expect(result.violations, isEmpty);
  });

  test('ignores a provider whose value is a function (arrow body)', () {
    // The provider's value is a callback; the repository call runs when the
    // caller invokes it, so there is no cached row that could go stale.
    final result = scan('''
final deleteFooProvider = Provider(
  (ref) => (String id) async {
    await ref.read(fooRepositoryProvider).deleteFoo(id);
  },
);
''');
    expect(result.repositoryReadingProviders, 0);
    expect(result.violations, isEmpty);
  });

  test('ignores a provider whose value is a function (block body)', () {
    final result = scan('''
final deleteFooProvider = Provider((ref) {
  return (String id) async {
    final repository = ref.read(fooRepositoryProvider);
    await repository.deleteFoo(id);
  };
});
''');
    expect(result.repositoryReadingProviders, 0);
    expect(result.violations, isEmpty);
  });

  test('still flags a provider that awaits a repository and returns data', () {
    // Guard against the function-valued rule swallowing ordinary providers.
    final result = scan('''
final fooProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fooRepositoryProvider);
  return repository.getFoo();
});
''');
    expect(result.violations, hasLength(1));
  });

  test('does not count a live watch* query as a repository read', () {
    // watchFindings is not a change tick, but it is still a live Drift query:
    // the provider re-emits on every write, so it cannot serve a stale value.
    final result = scan('''
final fooProvider = StreamProvider<int>((ref) {
  return ref.watch(fooRepositoryProvider).watchFindings();
});
''');
    expect(result.repositoryReadingProviders, 0);
    expect(result.violations, isEmpty);
  });

  test('does not count a chained tick call as a repository read', () {
    // A provider whose ONLY repository contact is subscribing to the tick is
    // not reading anything, so it must not be counted as a reader.
    final result = scan('''
final fooProvider = FutureProvider<int>((ref) async {
  ref.invalidateSelfWhen(ref.watch(fooRepositoryProvider).watchFooChanges());
  return 1;
});
''');
    expect(result.repositoryReadingProviders, 0);
    expect(result.violations, isEmpty);
  });

  test('treats a directly constructed repository as a repository', () {
    final result = scan('''
final fooProvider = FutureProvider<int>((ref) async {
  final repository = FooRepository();
  return repository.getFoo();
});
''');
    expect(result.violations, hasLength(1));
  });

  test('honours a // no-tick: marker with a reason', () {
    final result = scan('''
// no-tick: read fresh at action time, never renders a cached value
final fooProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fooRepositoryProvider);
  return repository.getFoo();
});
''');
    expect(result.violations, isEmpty);
  });

  test('honours a // no-tick: marker that sits above a doc comment', () {
    final result = scan('''
// no-tick: read fresh at action time, never renders a cached value
/// Some documentation about what this provider does.
final fooProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fooRepositoryProvider);
  return repository.getFoo();
});
''');
    expect(result.violations, isEmpty);
  });

  test('rejects a // no-tick: marker with an empty reason', () {
    final result = scan('''
// no-tick:
final fooProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fooRepositoryProvider);
  return repository.getFoo();
});
''');
    expect(result.violations, hasLength(1));
  });

  test(
    'reads the repository binding through ref.read as well as ref.watch',
    () {
      final result = scan('''
final fooProvider = FutureProvider<int>((ref) async {
  final repository = ref.read(fooRepositoryProvider);
  return repository.getFoo();
});
''');
      expect(result.violations, hasLength(1));
    },
  );

  test('flags each offending provider in a file separately', () {
    final result = scan('''
final okProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fooRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchFooChanges());
  return repository.getFoo();
});

final firstBadProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fooRepositoryProvider);
  return repository.getFoo();
});

final secondBadProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(barRepositoryProvider);
  return repository.getBar();
});
''');
    expect(result.violations.map((v) => v.provider), [
      'firstBadProvider',
      'secondBadProvider',
    ]);
    expect(result.repositoryReadingProviders, 3);
  });
}
