import 'dart:io';

import 'package:submersion/core/services/log_file_service.dart';

/// A log file service for tests that only need the provider to resolve
/// (debug mode, for example); it never writes under the system temp dir.
LogFileService testLogFileService() =>
    LogFileService(logDirectory: Directory.systemTemp.path);
