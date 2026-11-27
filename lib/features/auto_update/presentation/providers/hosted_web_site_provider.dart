import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/domain/hosted_web_site.dart';

/// Which of Submersion's own web sites this page is (issue #4481). Fixed for
/// the life of the page; tests override it to stand on either site.
final hostedWebSiteProvider = Provider<HostedWebSite>(
  (ref) => currentHostedWebSite,
);
