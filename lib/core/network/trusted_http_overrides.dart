import 'dart:io';

import 'package:submersion/core/network/app_security_context.dart';

/// Routes every default-context [HttpClient] in the Dart VM through the
/// platform-trusted [SecurityContext] from [appSecurityContext].
///
/// On Windows this is the only fix that reaches HTTP clients the app does not
/// construct itself: flutter_map / FMTC tile fetches and Flutter's
/// [NetworkImage] all create a bare `HttpClient()`, whose trust anchors come
/// from `HttpOverrides.current` at construction time. Installing this as
/// `HttpOverrides.global` in `main()` makes them -- and every `package:http`
/// client, which is an `IOClient` over the same `HttpClient` -- verify
/// against the Windows certificate store that Dart's default BoringSSL
/// context cannot read.
///
/// Off Windows [appSecurityContext] is null, so an explicit `context` (or
/// null) passes straight through to the default implementation: a
/// transparent no-op. An explicitly supplied context always wins over the
/// fallback.
class TrustedHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context ?? appSecurityContext());
  }
}
