import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/web/web_secure_storage_core.dart';

/// The browser's secure storage (issue #4121): a session map by default,
/// browser local storage once the user asks to be remembered, and the
/// switch moves every entry between the two.
void main() {
  late Map<String, String> local;
  late WebSecureStorageCore core;

  setUp(() {
    local = {'theme': 'dark'};
    core = WebSecureStorageCore(localStorage: local);
  });

  test('starts forgetting: nothing is remembered until asked', () {
    expect(core.remember, isFalse);
  });

  test('with remember off a write lands in the session only', () async {
    await core.write('s3.secret', 'hunter2');
    expect(await core.read('s3.secret'), 'hunter2');
    expect(local.keys, ['theme']);
    expect(core.keys, {'s3.secret'});
  });

  test('a reload with remember off forgets everything', () async {
    await core.write('s3.secret', 'hunter2');
    final reloaded = WebSecureStorageCore(localStorage: local);
    expect(await reloaded.read('s3.secret'), isNull);
    expect(reloaded.keys, isEmpty);
  });

  test('setRemember(true) moves the entries into local storage', () async {
    await core.write('s3.secret', 'hunter2');
    await core.write('passphrase', 'correct horse');
    await core.setRemember(true);
    expect(core.remember, isTrue);
    expect(local[WebSecureStorageCore.rememberKey], 'true');
    expect(
      local.keys.where((k) => k.startsWith('submersion.secure.')).toSet(),
      {'submersion.secure.s3.secret', 'submersion.secure.passphrase'},
    );
    // Lightly obscured: not the plain text at a glance in the dev tools.
    expect(local.values, isNot(contains('hunter2')));
    expect(await core.read('s3.secret'), 'hunter2');
    expect(await core.read('passphrase'), 'correct horse');
    // A reload with remember on keeps them.
    final reloaded = WebSecureStorageCore(localStorage: local);
    expect(reloaded.remember, isTrue);
    expect(await reloaded.read('passphrase'), 'correct horse');
    expect(reloaded.keys, {'s3.secret', 'passphrase'});
  });

  test('writes while remembered go straight to local storage', () async {
    await core.setRemember(true);
    await core.write('token', 'abc');
    expect(local.containsKey('submersion.secure.token'), isTrue);
    expect(await core.read('token'), 'abc');
    await core.delete('token');
    expect(local.containsKey('submersion.secure.token'), isFalse);
    expect(await core.read('token'), isNull);
  });

  test('setRemember(false) moves them back and local storage keeps only '
      'unprefixed keys', () async {
    await core.write('s3.secret', 'hunter2');
    await core.setRemember(true);
    await core.setRemember(false);
    expect(core.remember, isFalse);
    expect(local.keys, ['theme']);
    expect(await core.read('s3.secret'), 'hunter2');
    final reloaded = WebSecureStorageCore(localStorage: local);
    expect(await reloaded.read('s3.secret'), isNull);
  });

  test('delete removes the entry from whichever store holds it', () async {
    await core.write('a', '1');
    await core.delete('a');
    expect(await core.read('a'), isNull);
    expect(core.keys, isEmpty);
  });

  test('clearAll empties both stores and the flag', () async {
    await core.write('session-only', 'x');
    await core.setRemember(true);
    await core.write('remembered', 'y');
    await core.clearAll();
    expect(core.remember, isFalse);
    expect(core.keys, isEmpty);
    expect(local.keys, ['theme']);
    expect(await core.read('session-only'), isNull);
    expect(await core.read('remembered'), isNull);
  });

  test('a different prefix keeps its own entries apart', () async {
    final other = WebSecureStorageCore(localStorage: local, prefix: 'x.');
    await other.setRemember(true);
    await other.write('k', 'v');
    expect(local['x.k'], isNotNull);
    expect(core.keys, isEmpty);
  });
}
