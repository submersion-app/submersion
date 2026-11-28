import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/domain/entities/release_channel.dart';
import 'package:submersion/features/auto_update/domain/hosted_web_site.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';

/// Which of Submersion's own web sites this page is (issue #4481). Fixed for
/// the life of the page; tests override it to stand on either site.
final hostedWebSiteProvider = Provider<HostedWebSite>(
  (ref) => currentHostedWebSite,
);

/// The release channel this build runs, for advice that depends on it (the
/// newer-schema peer banner). The beta web site always serves the newest
/// beta, while a browser keeps no channel of its own, so there it is beta
/// whatever the stored preference says; anywhere else it is the stored one.
final effectiveReleaseChannelProvider = Provider<ReleaseChannel>(
  (ref) => ref.watch(hostedWebSiteProvider) == HostedWebSite.beta
      ? ReleaseChannel.beta
      : ref.watch(releaseChannelProvider),
);
