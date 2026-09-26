import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Chinese names signing in and out with the standard UI terms, 登录 and
/// 退出登录, everywhere.
///
/// The cloud sync sign-out button, its confirmation title and its confirm
/// action once read 签名出, a word-for-word calque of "sign" + "out". 签名
/// means a handwritten signature (the app's signature feature uses it in that
/// sense), so the calque is not Chinese; it reads as "signature out". Every
/// other account string in the file already used 登录 / 退出登录, so the
/// calque sat beside correct terminology for the same action.
///
/// Chinese has no word boundaries, so the scan cannot simply forbid the three
/// characters in a row: 加载签名出错 is 加载签名 ("load signature") followed by
/// 出错 ("error"), which is correct. The pattern excludes that 出错 reading.
final _calque = RegExp('签名出(?!错)');

void main() {
  test('no Chinese string uses the 签名出 calque', () {
    final arb =
        jsonDecode(
              File(
                p.join('lib', 'l10n', 'arb', 'app_zh.arb'),
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final offenders = arb.entries
        .where((e) => !e.key.startsWith('@'))
        .where((e) => e.value is String && _calque.hasMatch(e.value as String))
        .map((e) => e.key)
        .toList();
    expect(offenders, isEmpty);
  });

  test('cloud sync sign-out uses 退出登录', () {
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(zh.settings_cloudSync_signOut, '退出登录');
    expect(zh.settings_cloudSync_signOutDialog_signOut, '退出登录');
    expect(zh.settings_cloudSync_signOutDialog_title, '退出登录？');
  });

  test('the sign-in placeholder is translated', () {
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(zh.media_unavailablePlaceholder_signInRequired, '登录后查看');
  });
}
