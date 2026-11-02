import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Browser variant: holds the Web Lock [name] for the whole of [body]. Other
/// tabs asking for the same name wait their turn. Where the browser has no
/// Web Locks the body runs unlocked, as on native.
Future<T> withCrossTabLock<T>(String name, Future<T> Function() body) async {
  if (!(web.window.navigator as JSObject).has('locks')) return body();
  Future<T>? run;
  // The callback's promise is what holds the lock: it settles when the body
  // does. The body's own future is handed back below so the caller sees its
  // value or error; the promise swallows the error so the lock request is
  // not rejected, and being the body's first listener it also keeps the
  // error from surfacing as unhandled before the caller awaits it.
  JSPromise<JSAny?> granted(web.Lock? lock) {
    final started = run = body();
    return started
        .then<JSAny?>((_) => null, onError: (Object _, StackTrace _) => null)
        .toJS;
  }

  await web.window.navigator.locks.request(name, granted.toJS).toDart;
  final completed = run;
  if (completed == null) {
    throw StateError('the lock was granted but the body never ran');
  }
  return completed;
}
