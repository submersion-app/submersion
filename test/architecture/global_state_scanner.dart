/// Finds test code that replaces process-wide state and does not put it back.
///
/// CI runs many test files in one isolate (issue #2500), so whatever one file
/// leaves in a global is what the next file starts with. The scan is a pattern
/// match over source text: it proves a restore is written, not that it runs on
/// every path.
///
/// A restore is the previous value read into a variable, and that same
/// variable assigned back. Reading the value is not enough on its own.
library;

/// One assignment that nothing in the same file undoes.
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
final _httpAssignment = RegExp(r'\bHttpOverrides\.global\s*=(?!=)');
final _nullHandler = RegExp(
  r'setMockMethodCallHandler\([^;]*?,\s*null\s*,?\s*\)',
  dotAll: true,
);

/// Whether [code] reads [read] into a variable and assigns that same variable
/// to [target].
bool _isRestored(String code, {required String read, required String target}) {
  final capture = RegExp(
    '\\b([A-Za-z_]\\w*)\\s*=\\s*${RegExp.escape(read)}\\b',
  );
  final assigned = RegExp.escape(target);
  for (final match in capture.allMatches(code)) {
    final variable = RegExp.escape(match.group(1)!);
    if (RegExp('$assigned\\s*=\\s*$variable\\b').hasMatch(code)) return true;
  }
  return false;
}

/// Every assignment in [source] that replaces a global without the file also
/// putting back what was there.
List<GlobalStateOffence> scanForUnrestoredGlobals(String path, String source) {
  final lines = source.split('\n');
  // Comments may describe an assignment freely.
  final code = [for (final line in lines) line.split('//').first];
  final all = code.join('\n');
  final offences = <GlobalStateOffence>[];

  void flag(int index, String rule) {
    offences.add(
      GlobalStateOffence(
        path: path,
        line: index + 1,
        rule: rule,
        text: lines[index].trim(),
      ),
    );
  }

  final restoresDefaults = all.contains('applyGlobalTestDefaults');
  for (var i = 0; i < code.length; i++) {
    for (final match in _platformAssignment.allMatches(code[i])) {
      final instance = '${match.group(1)!}.instance';
      if (!_isRestored(all, read: instance, target: instance)) {
        flag(i, platformRule);
      }
    }
    if (_httpAssignment.hasMatch(code[i]) &&
        !_isRestored(
          all,
          read: 'HttpOverrides.current',
          target: 'HttpOverrides.global',
        )) {
      flag(i, httpRule);
    }
    if (!restoresDefaults) {
      for (final name in harnessDefaults) {
        final assignment = RegExp('\\b${RegExp.escape(name)}\\s*=(?!=)');
        if (assignment.hasMatch(code[i])) flag(i, harnessRule);
      }
    }
  }

  final mocksChannel =
      all.contains('setMockMethodCallHandler') &&
      mockedChannels.any(all.contains);
  final clearsChannel =
      all.contains('clearPathAndShareChannelMocks') ||
      _nullHandler.hasMatch(all);
  if (mocksChannel && !clearsChannel) {
    flag(
      code.indexWhere((line) => line.contains('setMockMethodCallHandler')),
      channelRule,
    );
  }
  return offences;
}
