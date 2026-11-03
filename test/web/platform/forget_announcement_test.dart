@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'package:submersion/core/platform/browser_origin_storage.dart';

/// Forget this device tells the site's other tabs, which would otherwise
/// keep the forgotten dives and credentials in memory (issue #4121).
void main() {
  test('a tab hears another tab forget the device', () async {
    final heard = Completer<void>();
    final stop = BrowserOriginStorage.onForgottenElsewhere(heard.complete);
    addTearDown(stop);

    // A second channel stands in for the other tab: a channel never hears
    // what it posted itself.
    final other = web.BroadcastChannel(BrowserOriginStorage.forgetChannel);
    addTearDown(() => other.close());
    other.postMessage('forgotten'.toJS);

    await heard.future.timeout(const Duration(seconds: 5));
  });

  test('announcing reaches a listener on another channel', () async {
    final heard = Completer<void>();
    final other = web.BroadcastChannel(BrowserOriginStorage.forgetChannel);
    addTearDown(() => other.close());
    other.onmessage = ((web.MessageEvent _) => heard.complete()).toJS;

    BrowserOriginStorage.announceForgotten();

    await heard.future.timeout(const Duration(seconds: 5));
  });
}
