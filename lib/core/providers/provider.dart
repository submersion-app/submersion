// Riverpod no longer re-exports the Override type in the public api, so we tap
// the internal export to keep existing tests/helper APIs compiling.
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
export 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:flutter_riverpod/legacy.dart';
export 'async_value_extensions.dart';

// Compatibility alias for Riverpod v2 Override type used in older tests
typedef Override = riverpod.Override;
