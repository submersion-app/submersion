/// The one MCP listener in the process.
///
/// Native builds serve MCP over loopback HTTP
/// (`agent_access_server_io.dart`). A browser page cannot listen on a port,
/// so the web variant refuses to start and reports itself stopped.
library;

export 'package:submersion/features/agent_access/data/server/agent_access_server_io.dart'
    if (dart.library.js_interop) 'package:submersion/features/agent_access/data/server/agent_access_server_web.dart';
export 'package:submersion/features/agent_access/data/server/agent_access_status.dart';
export 'package:submersion/features/agent_access/data/server/agent_server_spec.dart';
