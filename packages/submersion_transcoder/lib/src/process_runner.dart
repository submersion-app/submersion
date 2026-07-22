import 'dart:convert';
import 'dart:io';

/// Completed-process result (a dart:io-free mirror of ProcessResult so
/// fakes need no dart:io types).
class ProcessRunResult {
  const ProcessRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
  final int exitCode;
  final String stdout;
  final String stderr;
}

/// Result of a streamed process run: the exit code plus the captured stderr
/// (stdout is forwarded line-by-line during the run, not buffered here).
class StreamRunResult {
  const StreamRunResult({required this.exitCode, required this.stderr});
  final int exitCode;
  final String stderr;
}

/// Injectable seam over dart:io Process so engines are unit-testable
/// without external binaries.
abstract class TranscoderProcessRunner {
  Future<ProcessRunResult> run(String executable, List<String> arguments);

  /// Starts the process, forwarding each stdout line, and returns the exit
  /// code together with the captured stderr. Returning stderr through the
  /// contract keeps engines from having to know the concrete runner type to
  /// get diagnostics.
  Future<StreamRunResult> stream(
    String executable,
    List<String> arguments, {
    void Function(String line)? onStdoutLine,
  });
}

class SystemProcessRunner implements TranscoderProcessRunner {
  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments,
  ) async {
    try {
      final result = await Process.run(executable, arguments);
      return ProcessRunResult(
        exitCode: result.exitCode,
        stdout: result.stdout as String,
        stderr: result.stderr as String,
      );
    } on ProcessException catch (e) {
      return ProcessRunResult(exitCode: 127, stdout: '', stderr: e.message);
    }
  }

  @override
  Future<StreamRunResult> stream(
    String executable,
    List<String> arguments, {
    void Function(String line)? onStdoutLine,
  }) async {
    final Process process;
    try {
      process = await Process.start(executable, arguments);
    } on ProcessException catch (e) {
      return StreamRunResult(exitCode: 127, stderr: e.message);
    }
    final stderrBuf = StringBuffer();
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => onStdoutLine?.call(line));
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .forEach(stderrBuf.write);
    final code = await process.exitCode;
    await stdoutDone;
    await stderrDone;
    return StreamRunResult(exitCode: code, stderr: stderrBuf.toString());
  }
}
