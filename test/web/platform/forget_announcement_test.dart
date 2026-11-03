@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'package:submersion/core/platform/browser_origin_storage.dart';

/// Forget this device, a restore and a switch to or from the sample logbook
/// tell the site's other tabs to reload, since they would otherwise keep the
/// old library, dives or credentials in memory (issue #4121).
void main() {
  test('a tab hears another tab forget the device', () async {
    final heard = Completer<void>();
    final stop = BrowserOriginStorage.onReloadAskedElsewhere(heard.complete);
    addTearDown(stop);

    // A second channel stands in for the other tab: a channel never hears
    // what it posted itself.
    final other = web.BroadcastChannel(BrowserOriginStorage.reloadChannel);
    addTearDown(() => other.close());
    other.postMessage('forgotten'.toJS);

    await heard.future.timeout(const Duration(seconds: 5));
  });

  test('announcing reaches a listener on another channel', () async {
    final heard = Completer<void>();
    final other = web.BroadcastChannel(BrowserOriginStorage.reloadChannel);
    addTearDown(() => other.close());
    other.onmessage = ((web.MessageEvent _) => heard.complete()).toJS;

    BrowserOriginStorage.announceForgotten();

    await heard.future.timeout(const Duration(seconds: 5));
  });

  test('a restore or a sample logbook switch reloads the other tabs', () async {
    final heard = Completer<void>();
    final stop = BrowserOriginStorage.onReloadAskedElsewhere(heard.complete);
    addTearDown(stop);
    final other = web.BroadcastChannel(BrowserOriginStorage.reloadChannel);
    addTearDown(() => other.close());
    final relayed = Completer<void>();
    other.onmessage = ((web.MessageEvent _) => relayed.complete()).toJS;

    BrowserOriginStorage.announceLibraryChanged();

    // This tab's own listener stays quiet; another tab hears it.
    await relayed.future.timeout(const Duration(seconds: 5));
    expect(heard.isCompleted, isFalse);
  });
}
