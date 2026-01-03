// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod_framework
    show Override;
import 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:flutter_riverpod/legacy.dart';
export 'async_value_extensions.dart';

// Compatibility alias for Riverpod v2 Override type used in older tests
typedef Override = riverpod_framework.Override;
