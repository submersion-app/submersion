/// Finds test code that replaces process-wide state and does not put it back.
///
/// CI runs many test files in one isolate (issue #2500), so whatever one file
/// leaves in a global is what the next file starts with.
///
/// A restore is the previous value read into a variable, and that same
/// variable assigned back. It answers for the replacements in its own scope:
/// a `tearDown` for the group it is declared in, an `addTearDown` for the test
/// that registers it. A restore in one group does not excuse a replacement in
/// another.
///
/// The scan matches patterns in source text, with comments and string
/// contents masked out. It proves a restore is written, not that it runs on
/// every path.
library;

import 'source_mask.dart';

/// One assignment that nothing in its scope undoes.
class GlobalStateOffence {
  const GlobalStateOffence({
    required this.path,
    required this.line,
    required this.rule,
    required this.text,
  });

  final String path;
  final int line;
  final String rule;
  final String text;

  @override
  String toString() => '$path:$line: [$rule] $text';
}

/// Globals `test/flutter_test_config.dart` sets once per entrypoint.
const harnessDefaults = [
  'QualityScanScheduler.enabled',
  'SensorSummaryScheduler.enabled',
  'debugCanShareFiles',
];

/// Channels whose mock handlers change what the path provider and the share
/// sheet answer for every file that runs afterwards.
const mockedChannels = [
  'plugins.flutter.io/path_provider',
  'dev.fluttercommunity.plus/share',
];

const platformRule = 'platform singleton';
const httpRule = 'HTTP overrides';
const harnessRule = 'harness default';
const channelRule = 'channel mock';

final _platformAssignment = RegExp(r'\b([A-Z]\w*Platform)\.instance\s*=(?!=)');
final _harnessHelper = RegExp(r'\bapplyGlobalTestDefaults\b');
final _mockHandler = RegExp(r'\bsetMockMethodCallHandler\s*\(');
final _nullHandler = RegExp(
  r'setMockMethodCallHandler\([^;]*?,\s*null\s*,?\s*\)',
  dotAll: true,
);
final _teardown = RegExp(r'\b(tearDown|tearDownAll|addTearDown)\s*\(');
final _setUp = RegExp(r'\b(setUp|setUpAll)\s*\(');

/// The stretch of a file that a restore answers for.
class _Scope {
  const _Scope(this.block);

  /// Null when the restore answers for the whole file.
  final Block? block;

  bool covers(int offset) {
    final block = this.block;
    return block == null || (block.open < offset && offset < block.close);
  }
}

/// The scope a restore at [offset] answers for.
///
/// Inside a teardown, that is the block the teardown was declared in. A
/// teardown registered from `setUp` answers for whatever that `setUp` does.
/// Anywhere else, such as a `finally`, it is the block the restore sits in.
///
/// With [teardownOnly], a restore outside a teardown answers for nothing and
/// the result is null.
_Scope? _scopeOf(MaskedSource masked, int offset, {bool teardownOnly = false}) {
  final chain = masked.enclosing(offset);
  var index = chain.indexWhere(
    (block) => _teardown.hasMatch(masked.headerOf(block)),
  );
  if (index >= 0) {
    // The teardown's own block; the scope is the block around the call.
    index++;
  } else if (_teardown.hasMatch(masked.statementBefore(offset))) {
    // An arrow teardown, or a helper passed as a tear-off, has no block.
    index = 0;
  } else if (teardownOnly) {
    return null;
  } else {
    index = 0;
  }
  while (index < chain.length &&
      _setUp.hasMatch(masked.headerOf(chain[index]))) {
    index++;
  }
  return _Scope(index < chain.length ? chain[index] : null);
}

/// Every assignment in [source] that replaces a global with no restore in
/// scope.
List<GlobalStateOffence> scanForUnrestoredGlobals(String path, String source) {
  final masked = MaskedSource(source);
  final code = masked.code;
  final lines = source.split('\n');
  final flagged = <int, String>{};

  /// Flags each assignment to [target] that is not a restore and that no
  /// restore covers. A restore assigns back a variable that holds [read].
  void checkReplacements({
    required String read,
    required String target,
    required String rule,
  }) {
    final captured = {
      for (final match in RegExp(
        '\\b([A-Za-z_]\\w*)\\s*=\\s*${RegExp.escape(read)}\\b',
      ).allMatches(code))
        match.group(1)!,
    };
    final replacements = <int>[];
    final scopes = <_Scope>[];
    for (final match in RegExp(
      '\\b${RegExp.escape(target)}\\s*=(?!=)\\s*([A-Za-z_]\\w*)?',
    ).allMatches(code)) {
      if (captured.contains(match.group(1))) {
        scopes.add(_scopeOf(masked, match.start)!);
      } else {
        replacements.add(match.start);
      }
    }
    for (final offset in replacements) {
      if (!scopes.any((scope) => scope.covers(offset))) flagged[offset] = rule;
    }
  }

  final platforms = {
    for (final match in _platformAssignment.allMatches(code)) match.group(1)!,
  };
  for (final name in platforms) {
    checkReplacements(
      read: '$name.instance',
      target: '$name.instance',
      rule: platformRule,
    );
  }
  checkReplacements(
    read: 'HttpOverrides.current',
    target: 'HttpOverrides.global',
    rule: httpRule,
  );

  final helperScopes = [
    for (final match in _harnessHelper.allMatches(code))
      ?_scopeOf(masked, match.start, teardownOnly: true),
  ];
  for (final name in harnessDefaults) {
    final assignment = RegExp('\\b${RegExp.escape(name)}\\s*=(?!=)');
    for (final match in assignment.allMatches(code)) {
      if (!helperScopes.any((scope) => scope.covers(match.start))) {
        flagged[match.start] = harnessRule;
      }
    }
  }

  // Channel names live in strings, so they are looked for in the text that
  // keeps them. The calls are looked for in the code that does not.
  final handler = _mockHandler.firstMatch(code);
  final mocksChannel =
      handler != null && mockedChannels.any(masked.text.contains);
  final clearsChannel =
      code.contains('clearPathAndShareChannelMocks') ||
      _nullHandler.hasMatch(code);
  if (mocksChannel && !clearsChannel) flagged[handler.start] = channelRule;

  return [
    for (final offset in flagged.keys.toList()..sort())
      GlobalStateOffence(
        path: path,
        line: masked.lineOf(offset),
        rule: flagged[offset]!,
        text: lines[masked.lineOf(offset) - 1].trim(),
      ),
  ];
}
