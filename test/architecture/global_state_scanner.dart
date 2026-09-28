/// Finds test code that replaces process-wide state and does not put it back.
///
/// CI runs many test files in one isolate (issue #2500), so whatever one file
/// leaves in a global is what the next file starts with.
///
/// A restore is the previous value read into a variable, and that same
/// variable assigned back, in a teardown so that it runs even when a test
/// fails. It answers for the replacements in its own scope: a `tearDown` for
/// the group it is declared in, an `addTearDown` for the test that registers
/// it. A restore in one group does not excuse a replacement in another.
///
/// The foundation hooks (`debugPrint`, `FlutterError.onError` and
/// `debugDefaultTargetPlatformOverride`) are the exception: flutter_test
/// requires a `testWidgets` body to put them back before it ends, so a restore
/// anywhere in the same test counts.
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
  'GoogleFonts.config.allowRuntimeFetching',
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
const foundationRule = 'foundation hook';

final _platformAssignment = RegExp(r'\b([A-Z]\w*Platform)\.instance\s*=(?!=)');
final _harnessHelper = RegExp(r'\bapplyGlobalTestDefaults\b');
final _mockHandler = RegExp(r'\bsetMockMethodCallHandler\s*\(');
final _channelHelper = RegExp(r'\bclearPathAndShareChannelMocks\b');
final _controlFlow = RegExp(
  r'^\s*(try|finally|else|do|if\s*\(|for\s*\(|while\s*\(|switch\s*\(|catch\s*\(|on\s+\w)',
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

/// The scope a restore at [offset] answers for, or null when it answers for
/// nothing.
///
/// Inside a teardown, that is the block the teardown was declared in, and a
/// teardown registered from `setUp` answers for whatever that `setUp` serves.
/// Outside a teardown a restore counts only with [anywhere], and then it
/// answers for the function it sits in, read past any `try`, `if` or loop.
_Scope? _scopeOf(MaskedSource masked, int offset, {bool anywhere = false}) {
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
  } else if (anywhere) {
    index = 0;
    while (index < chain.length &&
        _controlFlow.hasMatch(masked.headerOf(chain[index]))) {
      index++;
    }
    return _Scope(index < chain.length ? chain[index] : null);
  } else {
    return null;
  }
  while (index < chain.length &&
      _setUp.hasMatch(masked.headerOf(chain[index]))) {
    index++;
  }
  return _Scope(index < chain.length ? chain[index] : null);
}

/// The offset of the `)` that closes the `(` at [open] in [code].
int _closingParen(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final char = code[i];
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return code.length;
}

/// The top-level arguments of the call whose `(` is at [open], as offset
/// ranges into the source.
List<({int start, int end})> _arguments(String code, int open) {
  final close = _closingParen(code, open);
  final arguments = <({int start, int end})>[];
  var depth = 0;
  var start = open + 1;
  for (var i = open + 1; i < close; i++) {
    final char = code[i];
    if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      depth--;
    } else if (char == ',' && depth == 0) {
      arguments.add((start: start, end: i));
      start = i + 1;
    }
  }
  if (code.substring(start, close).trim().isNotEmpty) {
    arguments.add((start: start, end: close));
  }
  return arguments;
}

/// The watched channel a mock handler call's first argument names, or null.
///
/// The argument is either a `MethodChannel('...')` expression or a variable
/// declared with one elsewhere in the file.
String? _channelOf(MaskedSource masked, ({int start, int end}) argument) {
  final written = masked.text.substring(argument.start, argument.end);
  for (final channel in mockedChannels) {
    if (written.contains("'$channel'") || written.contains('"$channel"')) {
      return channel;
    }
  }
  final name = RegExp(r'^\s*([A-Za-z_]\w*)\s*$').firstMatch(written)?.group(1);
  if (name == null) return null;
  final declaration = RegExp(
    '\\b${RegExp.escape(name)}\\s*=\\s*(?:const\\s+)?MethodChannel\\(\\s*[\'"]([^\'"]+)[\'"]',
  ).firstMatch(masked.text);
  final channel = declaration?.group(1);
  return mockedChannels.contains(channel) ? channel : null;
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
    bool anywhere = false,
  }) {
    final captured = {
      for (final match in RegExp(
        '\\b([A-Za-z_]\\w*)\\s*=\\s*${RegExp.escape(read)}\\b',
      ).allMatches(code))
        match.group(1)!,
    };
    final replacements = <int>[];
    final scopes = <_Scope?>[];
    for (final match in RegExp(
      '\\b${RegExp.escape(target)}\\s*=(?!=)\\s*([A-Za-z_]\\w*)?',
    ).allMatches(code)) {
      if (captured.contains(match.group(1))) {
        scopes.add(_scopeOf(masked, match.start, anywhere: anywhere));
      } else {
        replacements.add(match.start);
      }
    }
    for (final offset in replacements) {
      if (!scopes.any((scope) => scope?.covers(offset) ?? false)) {
        flagged[offset] = rule;
      }
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
  for (final hook in ['debugPrint', 'FlutterError.onError']) {
    checkReplacements(
      read: hook,
      target: hook,
      rule: foundationRule,
      anywhere: true,
    );
  }

  // The target platform override has no saved value to put back: it is
  // restored by assigning null.
  final platformOverride = RegExp(
    r'\bdebugDefaultTargetPlatformOverride\s*=(?!=)\s*(null\b)?',
  );
  final overrideScopes = <_Scope?>[];
  final overrides = <int>[];
  for (final match in platformOverride.allMatches(code)) {
    if (match.group(1) != null) {
      overrideScopes.add(_scopeOf(masked, match.start, anywhere: true));
    } else {
      overrides.add(match.start);
    }
  }
  for (final offset in overrides) {
    if (!overrideScopes.any((scope) => scope?.covers(offset) ?? false)) {
      flagged[offset] = foundationRule;
    }
  }

  final helperScopes = [
    for (final match in _harnessHelper.allMatches(code))
      ?_scopeOf(masked, match.start),
  ];
  for (final name in harnessDefaults) {
    final assignment = RegExp('\\b${RegExp.escape(name)}\\s*=(?!=)');
    for (final match in assignment.allMatches(code)) {
      if (!helperScopes.any((scope) => scope.covers(match.start))) {
        flagged[match.start] = harnessRule;
      }
    }
  }

  // A mock handler answers for every later file until it is removed, by
  // setting it to null or with clearPathAndShareChannelMocks, in a teardown
  // whose scope holds the call that installed it.
  final installs = <({int offset, String channel})>[];
  final clears = <String, List<_Scope?>>{
    for (final channel in mockedChannels)
      channel: [
        for (final match in _channelHelper.allMatches(code))
          _scopeOf(masked, match.start),
      ],
  };
  for (final match in _mockHandler.allMatches(code)) {
    final arguments = _arguments(code, match.end - 1);
    if (arguments.length < 2) continue;
    final channel = _channelOf(masked, arguments[0]);
    if (channel == null) continue;
    final handler = code.substring(arguments[1].start, arguments[1].end);
    if (handler.trim() == 'null') {
      clears[channel]!.add(_scopeOf(masked, match.start));
    } else {
      installs.add((offset: match.start, channel: channel));
    }
  }
  for (final install in installs) {
    final covered = clears[install.channel]!.any(
      (scope) => scope?.covers(install.offset) ?? false,
    );
    if (!covered) flagged[install.offset] = channelRule;
  }

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
